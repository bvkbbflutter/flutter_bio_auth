package com.vinay.flutter_bio_auth.model

/** Mirrors lib/src/liveness_challenge.dart LivenessChallenge. */
enum class LivenessChallenge {
    blink, smile, turnLeft, turnRight, lookUp, lookDown, moveCloser, moveAway
}

/** Mirrors lib/src/biometric_failure_reason.dart. */
enum class FaceAuthenticationFailureReason {
    faceNotDetected, multipleFacesDetected, poorFaceQuality, livenessFailed,
    challengeTimeout, antiSpoofFailed, faceMismatch, templateNotFound,
    templateDecryptionFailed, modelUnavailable, modelVersionMismatch,
    sessionTimeout, cameraPermissionDenied, cameraUnavailable, cancelled, unknown
}

/** Mirrors lib/src/biometric_error.dart FaceBiometricErrorCode. Also
 *  used as the PlatformException `code` so the Dart side can map it
 *  back without a lossy string round trip. */
enum class FaceBiometricErrorCode {
    cameraPermissionDenied, cameraUnavailable, faceNotDetected,
    multipleFacesDetected, faceTooSmall, faceTooLarge, faceNotCentered,
    poorFaceQuality, modelUnavailable, modelInitializationFailed,
    embeddingGenerationFailed, templateNotFound, templateDecryptionFailed,
    livenessFailed, antiSpoofFailed, faceMismatch, timeout, storageError,
    encryptionError, platformError, invalidConfiguration, notInitialized
}

/** Native exception type every engine throws; the plugin's method
 *  dispatcher converts these into PlatformExceptions with `code` set
 *  to [errorCode].name, never leaking a raw native stack trace message
 *  containing frame/template data. */
class BiometricException(
    val errorCode: FaceBiometricErrorCode,
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

data class FaceBoundingBox(val left: Double, val top: Double, val width: Double, val height: Double) {
    fun toMap(): Map<String, Any> = mapOf("left" to left, "top" to top, "width" to width, "height" to height)
}

data class FaceLandmarkPoint(val x: Double, val y: Double) {
    fun toMap(): Map<String, Any> = mapOf("x" to x, "y" to y)
}

/** One frame's worth of native face-detector output. Produced entirely
 *  by ML Kit's on-device face detector -- no bundled model required. */
data class FaceDetectionResult(
    val faceCount: Int,
    val trackingId: Int?,
    val boundingBox: FaceBoundingBox?,
    val landmarks: List<FaceLandmarkPoint>,
    val yawDegrees: Double?,
    val pitchDegrees: Double?,
    val rollDegrees: Double?,
    val leftEyeOpenProbability: Double?,
    val rightEyeOpenProbability: Double?,
    val smilingProbability: Double?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "faceCount" to faceCount,
        "trackingId" to trackingId,
        "boundingBox" to boundingBox?.toMap(),
        "landmarks" to landmarks.map { it.toMap() },
        "yawDegrees" to yawDegrees,
        "pitchDegrees" to pitchDegrees,
        "rollDegrees" to rollDegrees,
        "leftEyeOpenProbability" to leftEyeOpenProbability,
        "rightEyeOpenProbability" to rightEyeOpenProbability,
        "smilingProbability" to smilingProbability,
    )

    val hasSingleFace: Boolean get() = faceCount == 1
    val hasMultipleFaces: Boolean get() = faceCount > 1
    val hasNoFace: Boolean get() = faceCount == 0

    companion object {
        fun noFace() = FaceDetectionResult(0, null, null, emptyList(), null, null, null, null, null, null)
    }
}

data class FaceQualityResult(
    val overallScore: Double,
    val isBlurry: Boolean,
    val isTooSmall: Boolean,
    val isTooLarge: Boolean,
    val isCentered: Boolean,
    val isFrontal: Boolean,
    val brightness: Double,
) {
    val isAcceptable: Boolean
        get() = !isBlurry && !isTooSmall && !isTooLarge && isCentered && isFrontal

    fun toMap(): Map<String, Any> = mapOf(
        "overallScore" to overallScore, "isBlurry" to isBlurry, "isTooSmall" to isTooSmall,
        "isTooLarge" to isTooLarge, "isCentered" to isCentered, "isFrontal" to isFrontal,
        "brightness" to brightness,
    )
}

enum class AntiSpoofReason {
    live, photo, screenReplay, videoReplay, suspiciousTexture, suspiciousMotion,
    lowConfidence, modelUnavailable, unknown
}

data class AntiSpoofResult(val isLive: Boolean, val confidence: Double, val reason: AntiSpoofReason) {
    fun toMap(): Map<String, Any> = mapOf("isLive" to isLive, "confidence" to confidence, "reason" to reason.name)

    companion object {
        /** Absence of a configured model must never read as a pass. */
        val UNAVAILABLE = AntiSpoofResult(isLive = false, confidence = 0.0, reason = AntiSpoofReason.modelUnavailable)
    }
}

data class LivenessResult(
    val passed: Boolean,
    val overallScore: Double,
    val completedChallenges: List<LivenessChallenge>,
    val failedChallenge: LivenessChallenge?,
) {
    fun toMap(): Map<String, Any?> = mapOf(
        "passed" to passed,
        "overallScore" to overallScore,
        "completedChallenges" to completedChallenges.map { it.name },
        "failedChallenge" to failedChallenge?.name,
    )
}

/** A face crop plus the metadata FaceAlignment/embedding engines need;
 *  never serialized across the platform channel. */
data class FaceCrop(
    val alignedPixels: FloatArray, // normalized, aligned, resized RGB tensor
    val width: Int,
    val height: Int,
    val quality: FaceQualityResult,
)

data class FaceTemplateNative(
    val version: Int,
    val modelVersion: String,
    val embeddingDimension: Int,
    val embedding: FloatArray,
    val createdAtEpochMillis: Long,
) {
    companion object {
        const val CURRENT_TEMPLATE_VERSION = 1
    }
}
