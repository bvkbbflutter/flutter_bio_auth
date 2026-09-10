package com.vinay.flutter_bio_auth

import android.graphics.Bitmap
import com.vinay.flutter_bio_auth.model.AntiSpoofResult
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceAuthenticationFailureReason
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import com.vinay.flutter_bio_auth.model.FaceQualityResult
import com.vinay.flutter_bio_auth.model.FaceTemplateNative
import com.vinay.flutter_bio_auth.model.LivenessChallenge

/** Common contract [FaceBiometricPlugin] drives a session through. */
interface SessionRunner {
    val requiresBitmap: Boolean get() = false
    fun onFrame(bitmap: Bitmap?, detection: FaceDetectionResult)
    fun fail(error: BiometricException)
    fun reset()
    fun cancel()
}

private fun buildQualityAnalyzer(minSize: Double, maxSize: Double, centered: Boolean) =
    FaceQualityAnalyzer(minimumFaceSize = minSize, maximumFaceSize = maxSize, requireCentered = centered)

/**
 * Drives: detect -> single-face check -> quality gate -> (optional)
 * liveness -> capture N good-quality aligned samples -> generate an
 * embedding per sample -> mean-aggregate -> L2-normalize -> encrypt ->
 * store. Never builds a template from a single frame (see README
 * "Face enrollment" / "Multiple embeddings").
 */
class EnrollmentSession(
    private val userId: String,
    private val embeddingEngine: FaceEmbeddingEngine,
    private val faceAlignment: FaceAlignment,
    private val storage: BiometricTemplateStorage,
    private val minimumFaceSize: Double,
    private val maximumFaceSize: Double,
    private val requireCenteredFace: Boolean,
    private val requireSingleFace: Boolean,
    private val requiredSamples: Int,
    private val sessionTimeoutMillis: Long,
    private val enableLiveness: Boolean,
    private val livenessSequence: List<LivenessChallenge>,
    private val challengeTimeoutMillis: Long,
    private val emitState: (StateName) -> Unit,
    private val onComplete: (Map<String, Any?>) -> Unit,
    private val onError: (BiometricException) -> Unit,
) : SessionRunner {

    private val startedAt = System.currentTimeMillis()
    private val tracker = FaceTracker()
    private val qualityAnalyzer = buildQualityAnalyzer(minimumFaceSize, maximumFaceSize, requireCenteredFace)
    private var liveness = LivenessEngine(livenessSequence, challengeTimeoutMillis)
    private var livenessDone = !enableLiveness

    private val capturedEmbeddings = mutableListOf<FloatArray>()
    private var finished = false

    override val requiresBitmap: Boolean get() = livenessDone

    override fun onFrame(bitmap: Bitmap?, detection: FaceDetectionResult) {
        if (finished) return
        if (System.currentTimeMillis() - startedAt > sessionTimeoutMillis) {
            return complete(
                success = false,
                samplesUsed = capturedEmbeddings.size,
                reason = FaceAuthenticationFailureReason.sessionTimeout,
            )
        }

        if (requireSingleFace && detection.hasMultipleFaces) return
        if (detection.hasNoFace) { emitState(StateName.DETECTING_FACE); return }
        emitState(StateName.FACE_DETECTED)

        val smoothed = tracker.update(detection)

        if (!livenessDone) {
            emitState(StateName.RUNNING_LIVENESS)
            val outcome = liveness.onFrame(smoothed)
            if (outcome?.timedOut == true && System.currentTimeMillis() - startedAt >= sessionTimeoutMillis) {
                return complete(false, capturedEmbeddings.size, FaceAuthenticationFailureReason.challengeTimeout)
            }
            if (liveness.isFinished) {
                val result = liveness.finish()
                if (!result.passed) {
                    return complete(false, capturedEmbeddings.size, FaceAuthenticationFailureReason.livenessFailed)
                }
                livenessDone = true
            } else {
                return // still working through challenges before capturing samples
            }
        }

        if (bitmap == null) return
        emitState(StateName.VALIDATING_FACE)
        val box = detection.boundingBox ?: return
        val (sharpness, brightness) = faceAlignment.estimateSharpnessAndBrightness(bitmap)
        val quality: FaceQualityResult = qualityAnalyzer.analyze(detection, sharpness, brightness)
        if (!quality.isAcceptable) return // wait for a better frame; no error, just keep sampling

        if (!embeddingEngine.isAvailable) {
            return complete(false, capturedEmbeddings.size, FaceAuthenticationFailureReason.modelUnavailable)
        }

        try {
            emitState(StateName.GENERATING_EMBEDDING)
            val eyeLandmarks = detection.landmarks
            if (eyeLandmarks.size < 2) return
            val leftEyePx = Pair(
                (eyeLandmarks[0].x * bitmap.width).toFloat(),
                (eyeLandmarks[0].y * bitmap.height).toFloat(),
            )
            val rightEyePx = Pair(
                (eyeLandmarks[1].x * bitmap.width).toFloat(),
                (eyeLandmarks[1].y * bitmap.height).toFloat(),
            )
            val tensor = faceAlignment.alignAndNormalize(
                sourceBitmap = bitmap,
                boxLeft = (box.left * bitmap.width).toInt(),
                boxTop = (box.top * bitmap.height).toInt(),
                boxWidth = (box.width * bitmap.width).toInt(),
                boxHeight = (box.height * bitmap.height).toInt(),
                leftEyePx = leftEyePx,
                rightEyePx = rightEyePx,
            )
            val embedding = embeddingEngine.generateEmbedding(tensor)
            capturedEmbeddings.add(embedding)
        } catch (e: BiometricException) {
            // Skip this frame rather than aborting the whole session on
            // a single bad sample; only abort via the timeout path above.
            return
        }

        if (capturedEmbeddings.size >= requiredSamples) {
            val aggregated = aggregate(capturedEmbeddings)
            val template = FaceTemplateNative(
                version = FaceTemplateNative.CURRENT_TEMPLATE_VERSION,
                modelVersion = embeddingEngine.modelVersion,
                embeddingDimension = embeddingEngine.embeddingDimension,
                embedding = aggregated,
                createdAtEpochMillis = System.currentTimeMillis(),
            )
            try {
                storage.save(userId, template)
            } catch (e: BiometricException) {
                return complete(false, capturedEmbeddings.size, FaceAuthenticationFailureReason.unknown)
            }
            complete(true, capturedEmbeddings.size, null)
        }
    }

    /** Mean-aggregate then L2-normalize. Isolated in its own function
     *  per README §11 so the aggregation strategy can be swapped
     *  (e.g. median, quality-weighted mean) without touching the rest
     *  of the session logic. */
    private fun aggregate(embeddings: List<FloatArray>): FloatArray {
        val dim = embeddings[0].size
        val mean = FloatArray(dim)
        for (e in embeddings) for (i in 0 until dim) mean[i] += e[i] / embeddings.size
        var normSq = 0.0
        for (v in mean) normSq += v.toDouble() * v
        val norm = kotlin.math.sqrt(normSq)
        if (norm == 0.0) return mean
        return FloatArray(dim) { i -> (mean[i] / norm).toFloat() }
    }

    private fun complete(success: Boolean, samplesUsed: Int, reason: FaceAuthenticationFailureReason?) {
        finished = true
        emitState(if (success) StateName.SUCCESS else StateName.FAILED)
        onComplete(
            mapOf(
                "success" to success,
                "userId" to userId,
                "samplesUsed" to samplesUsed,
                "durationMs" to (System.currentTimeMillis() - startedAt),
                "failureReason" to reason?.name,
            ),
        )
    }

    override fun fail(error: BiometricException) {
        if (finished) return
        finished = true
        emitState(StateName.ERROR)
        onError(error)
    }

    override fun reset() {
        finished = false
        capturedEmbeddings.clear()
        tracker.reset()
        liveness = LivenessEngine(livenessSequence, challengeTimeoutMillis)
        livenessDone = !enableLiveness
    }

    override fun cancel() { finished = true }
}

/**
 * Drives: detect -> single-face check -> quality gate -> (optional)
 * liveness -> (optional) anti-spoof -> align -> embed -> compare
 * against the decrypted enrolled template -> AuthenticationEngine
 * decision.
 */
class AuthenticationSession(
    private val userId: String,
    private val enrolledTemplate: FaceTemplateNative,
    private val embeddingEngine: FaceEmbeddingEngine,
    private val antiSpoofEngine: AntiSpoofEngine,
    private val faceAlignment: FaceAlignment,
    private val faceMatcher: FaceMatcher,
    private val authenticationEngine: AuthenticationEngine,
    private val minimumFaceSize: Double,
    private val maximumFaceSize: Double,
    private val requireCenteredFace: Boolean,
    private val requireSingleFace: Boolean,
    private val sessionTimeoutMillis: Long,
    private val enableLiveness: Boolean,
    private val livenessSequence: List<LivenessChallenge>,
    private val challengeTimeoutMillis: Long,
    private val emitState: (StateName) -> Unit,
    private val onComplete: (Map<String, Any?>) -> Unit,
    private val onError: (BiometricException) -> Unit,
) : SessionRunner {

    private val startedAt = System.currentTimeMillis()
    private val tracker = FaceTracker()
    private val qualityAnalyzer = buildQualityAnalyzer(minimumFaceSize, maximumFaceSize, requireCenteredFace)
    private var liveness = LivenessEngine(livenessSequence, challengeTimeoutMillis)
    private var livenessDone = !enableLiveness
    private var livenessScore = if (enableLiveness) 0.0 else 1.0
    private var livenessPassed = !enableLiveness
    private var finished = false

    override val requiresBitmap: Boolean get() = livenessDone

    override fun onFrame(bitmap: Bitmap?, detection: FaceDetectionResult) {
        if (finished) return
        if (System.currentTimeMillis() - startedAt > sessionTimeoutMillis) {
            return complete(makeFailure(FaceAuthenticationFailureReason.sessionTimeout))
        }

        if (requireSingleFace && detection.hasMultipleFaces) return
        if (detection.hasNoFace) { emitState(StateName.DETECTING_FACE); return }
        emitState(StateName.FACE_DETECTED)

        val smoothed = tracker.update(detection)

        if (!livenessDone) {
            emitState(StateName.RUNNING_LIVENESS)
            val outcome = liveness.onFrame(smoothed)
            if (outcome?.timedOut == true && System.currentTimeMillis() - startedAt >= sessionTimeoutMillis) {
                return complete(makeFailure(FaceAuthenticationFailureReason.challengeTimeout))
            }
            if (liveness.isFinished) {
                val result = liveness.finish()
                livenessPassed = result.passed
                livenessScore = result.overallScore
                livenessDone = true
                if (!result.passed) {
                    return complete(makeFailure(FaceAuthenticationFailureReason.livenessFailed))
                }
            } else {
                return
            }
        }

        if (bitmap == null) return
        emitState(StateName.VALIDATING_FACE)
        val box = detection.boundingBox ?: return
        val (sharpness, brightness) = faceAlignment.estimateSharpnessAndBrightness(bitmap)
        val quality = qualityAnalyzer.analyze(detection, sharpness, brightness)
        if (!quality.isAcceptable) return

        if (!embeddingEngine.isAvailable) {
            return complete(makeFailure(FaceAuthenticationFailureReason.modelUnavailable))
        }

        val eyeLandmarks = detection.landmarks
        if (eyeLandmarks.size < 2) return

        try {
            emitState(StateName.GENERATING_EMBEDDING)
            val leftEyePx = Pair((eyeLandmarks[0].x * bitmap.width).toFloat(), (eyeLandmarks[0].y * bitmap.height).toFloat())
            val rightEyePx = Pair((eyeLandmarks[1].x * bitmap.width).toFloat(), (eyeLandmarks[1].y * bitmap.height).toFloat())
            val tensor = faceAlignment.alignAndNormalize(
                sourceBitmap = bitmap,
                boxLeft = (box.left * bitmap.width).toInt(),
                boxTop = (box.top * bitmap.height).toInt(),
                boxWidth = (box.width * bitmap.width).toInt(),
                boxHeight = (box.height * bitmap.height).toInt(),
                leftEyePx = leftEyePx,
                rightEyePx = rightEyePx,
            )

            emitState(StateName.CHECKING_ANTI_SPOOF)
            val antiSpoofResult: AntiSpoofResult = antiSpoofEngine.analyze(tensor)

            emitState(StateName.GENERATING_EMBEDDING)
            val liveEmbedding = embeddingEngine.generateEmbedding(tensor)

            emitState(StateName.MATCHING_FACE)
            val similarity = faceMatcher.cosineSimilarity(liveEmbedding, enrolledTemplate.embedding)

            emitState(StateName.AUTHENTICATING)
            val decision = authenticationEngine.decide(similarity, livenessPassed, livenessScore, antiSpoofResult)

            complete(
                mapOf(
                    "authenticated" to decision.authenticated,
                    "userId" to userId,
                    "similarity" to decision.similarity,
                    "livenessScore" to decision.livenessScore,
                    "antiSpoofScore" to decision.antiSpoofScore,
                    "durationMs" to (System.currentTimeMillis() - startedAt),
                    "failureReason" to decision.failureReason?.name,
                ),
            )
        } catch (e: BiometricException) {
            return complete(makeFailure(FaceAuthenticationFailureReason.unknown))
        }
    }

    private fun makeFailure(reason: FaceAuthenticationFailureReason): Map<String, Any?> = mapOf(
        "authenticated" to false,
        "userId" to userId,
        "similarity" to 0.0,
        "livenessScore" to livenessScore,
        "antiSpoofScore" to 0.0,
        "durationMs" to (System.currentTimeMillis() - startedAt),
        "failureReason" to reason.name,
    )

    private fun complete(resultMap: Map<String, Any?>) {
        finished = true
        emitState(if (resultMap["authenticated"] == true) StateName.SUCCESS else StateName.FAILED)
        onComplete(resultMap)
    }

    override fun fail(error: BiometricException) {
        if (finished) return
        finished = true
        emitState(StateName.ERROR)
        onError(error)
    }

    override fun reset() {
        finished = false
        tracker.reset()
        liveness = LivenessEngine(livenessSequence, challengeTimeoutMillis)
        livenessDone = !enableLiveness
        livenessPassed = !enableLiveness
        livenessScore = if (enableLiveness) 0.0 else 1.0
    }

    override fun cancel() { finished = true }
}
