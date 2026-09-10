package com.vinay.flutter_bio_auth

import android.graphics.Bitmap
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import com.vinay.flutter_bio_auth.model.LivenessChallenge
import com.vinay.flutter_bio_auth.model.LivenessResult

/**
 * Dedicated session for standalone active liveness verification.
 * Does NOT require any face-embedding model or anti-spoof model.
 *
 * Flow: detect face -> check size & centering -> sequence through
 * configured active liveness challenges (blink, smile, turns, etc.) ->
 * return [LivenessResult] with passed/failed and score metrics.
 */
class LivenessSession(
    private val minimumFaceSize: Double,
    private val maximumFaceSize: Double,
    private val requireCenteredFace: Boolean,
    private val requireSingleFace: Boolean,
    private val sessionTimeoutMillis: Long,
    private val livenessSequence: List<LivenessChallenge>,
    private val challengeTimeoutMillis: Long,
    private val emitState: (StateName) -> Unit,
    private val emitChallengeProgress: (LivenessChallenge, String, Double, Double, Boolean, Boolean) -> Unit,
    private val onComplete: (Map<String, Any?>) -> Unit,
    private val onError: (BiometricException) -> Unit,
) : SessionRunner {

    private val startedAt = System.currentTimeMillis()
    private val tracker = FaceTracker()
    private val qualityAnalyzer = FaceQualityAnalyzer(
        minimumFaceSize = minimumFaceSize,
        maximumFaceSize = maximumFaceSize,
        requireCentered = requireCenteredFace,
    )
    private var liveness = LivenessEngine(livenessSequence, challengeTimeoutMillis)
    private var finished = false
    override val requiresBitmap: Boolean get() = false

    override fun onFrame(bitmap: Bitmap?, detection: FaceDetectionResult) {
        if (finished) return

        if (System.currentTimeMillis() - startedAt > sessionTimeoutMillis) {
            val result = LivenessResult(
                passed = false,
                overallScore = 0.0,
                completedChallenges = emptyList(),
                failedChallenge = liveness.currentChallenge,
            )
            return complete(result)
        }

        if (requireSingleFace && detection.hasMultipleFaces) {
            emitState(StateName.DETECTING_FACE)
            return
        }

        if (detection.hasNoFace) {
            emitState(StateName.DETECTING_FACE)
            return
        }

        emitState(StateName.FACE_DETECTED)
        val smoothed = tracker.update(detection)

        // Ensure face is within reasonable tracking bounds; do not drop frames
        // on isCentered during active head-turns/tilts
        val box = detection.boundingBox
        val faceHeight = box?.height ?: 0.0
        if (faceHeight < 0.08 || faceHeight > 0.95) {
            emitState(StateName.VALIDATING_FACE)
            return
        }

        emitState(StateName.RUNNING_LIVENESS)
        val current = liveness.currentChallenge ?: run {
            if (liveness.isFinished) {
                complete(liveness.finish())
            }
            return
        }

        val outcome = liveness.onFrame(smoothed)
        if (outcome != null) {
            val instruction = challengeInstruction(current)
            emitChallengeProgress(
                current,
                instruction,
                outcome.progress,
                outcome.confidence,
                outcome.completed,
                outcome.timedOut,
            )
            if (outcome.timedOut && System.currentTimeMillis() - startedAt >= sessionTimeoutMillis) {
                complete(liveness.finish())
                return
            }
        }

        if (liveness.isFinished) {
            val result = liveness.finish()
            complete(result)
        }
    }

    private fun complete(result: LivenessResult) {
        finished = true
        emitState(if (result.passed) StateName.SUCCESS else StateName.FAILED)
        onComplete(result.toMap())
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
    }

    override fun cancel() {
        finished = true
    }

    private fun challengeInstruction(challenge: LivenessChallenge): String = when (challenge) {
        LivenessChallenge.blink -> "Blink both eyes"
        LivenessChallenge.smile -> "Smile"
        LivenessChallenge.turnLeft -> "Turn your head to the left"
        LivenessChallenge.turnRight -> "Turn your head to the right"
        LivenessChallenge.lookUp -> "Tilt your head up"
        LivenessChallenge.lookDown -> "Tilt your head down"
        LivenessChallenge.moveCloser -> "Move closer to the camera"
        LivenessChallenge.moveAway -> "Move away from the camera"
    }
}
