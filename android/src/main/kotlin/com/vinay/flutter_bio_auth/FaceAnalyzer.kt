package com.vinay.flutter_bio_auth

import androidx.camera.core.ImageProxy
import com.vinay.flutter_bio_auth.model.FaceBoundingBox
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import com.vinay.flutter_bio_auth.model.FaceLandmarkPoint
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.Face
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetector
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark

/**
 * Wraps Google's on-device ML Kit Face Detector.
 *
 * ML Kit ships its detection model via Google Play services and is
 * downloaded/managed by Play services itself the first time it's
 * used -- the plugin bundles zero model bytes for this. Provides
 * bounding box, 2D landmarks, head Euler angles (yaw/pitch/roll), and
 * classification probabilities (eye-open, smiling), which is
 * everything [FaceTracker], [FaceQualityAnalyzer], and the liveness
 * detectors need.
 */
class FaceAnalyzer {

    private val detector: FaceDetector by lazy {
        val options = FaceDetectorOptions.Builder()
            .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
            .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
            .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
            .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
            .enableTracking()
            .setMinFaceSize(0.10f)
            .build()
        FaceDetection.getClient(options)
    }

    /**
     * Analyzes one CameraX frame. Caller owns [imageProxy] lifecycle
     * and must close it after the returned Task-derived work
     * completes; this method itself never closes it (see
     * CameraManager, which throttles frames and closes them in a
     * finally block).
     */
    fun analyze(
        imageProxy: ImageProxy,
        onResult: (FaceDetectionResult) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val mediaImage = imageProxy.image ?: run {
            onResult(FaceDetectionResult.noFace())
            return
        }
        val rotation = imageProxy.imageInfo.rotationDegrees
        val input = InputImage.fromMediaImage(mediaImage, rotation)

        detector.process(input)
            .addOnSuccessListener { faces -> onResult(toDetectionResult(faces, input.width, input.height)) }
            .addOnFailureListener { e -> onError(e) }
    }

    /**
     * Still-image counterpart to [analyze], used by `compare()` where
     * there is no live [ImageProxy] -- only a decoded [Bitmap] from
     * the bytes the caller passed across the platform channel. Shares
     * the same lazily-built [detector] (and therefore the same
     * [FaceDetectorOptions]) so still-image and live-frame detection
     * stay consistent.
     */
    fun analyzeBitmap(
        bitmap: android.graphics.Bitmap,
        onResult: (FaceDetectionResult) -> Unit,
        onError: (Throwable) -> Unit,
    ) {
        val input = InputImage.fromBitmap(bitmap, 0)
        detector.process(input)
            .addOnSuccessListener { faces -> onResult(toDetectionResult(faces, input.width, input.height)) }
            .addOnFailureListener { e -> onError(e) }
    }

    private fun toDetectionResult(faces: List<Face>, frameWidth: Int, frameHeight: Int): FaceDetectionResult {
        if (faces.isEmpty()) return FaceDetectionResult.noFace()
        if (faces.size > 1) {
            // Still report count so the controller can raise
            // multipleFacesDetected without discarding the signal.
            return FaceDetectionResult(
                faceCount = faces.size, trackingId = null, boundingBox = null,
                landmarks = emptyList(), yawDegrees = null, pitchDegrees = null,
                rollDegrees = null, leftEyeOpenProbability = null,
                rightEyeOpenProbability = null, smilingProbability = null,
            )
        }

        val face = faces[0]
        val box = face.boundingBox
        val normalizedBox = FaceBoundingBox(
            left = (box.left.toDouble() / frameWidth).coerceIn(0.0, 1.0),
            top = (box.top.toDouble() / frameHeight).coerceIn(0.0, 1.0),
            width = (box.width().toDouble() / frameWidth),
            height = (box.height().toDouble() / frameHeight),
        )

        val landmarks = mutableListOf<FaceLandmarkPoint>()
        val leftEyePos = face.getLandmark(FaceLandmark.LEFT_EYE)?.position
        val rightEyePos = face.getLandmark(FaceLandmark.RIGHT_EYE)?.position
        if (leftEyePos != null && rightEyePos != null) {
            landmarks.add(FaceLandmarkPoint((leftEyePos.x / frameWidth).toDouble().coerceIn(0.0, 1.0), (leftEyePos.y / frameHeight).toDouble().coerceIn(0.0, 1.0)))
            landmarks.add(FaceLandmarkPoint((rightEyePos.x / frameWidth).toDouble().coerceIn(0.0, 1.0), (rightEyePos.y / frameHeight).toDouble().coerceIn(0.0, 1.0)))
        } else {
            // Robust fallback: Anatomically estimate eye positions from face box geometry
            // so alignment never swaps eyes with nose/mouth.
            val estLeftX = (box.left + box.width() * 0.35f) / frameWidth
            val estRightX = (box.left + box.width() * 0.65f) / frameWidth
            val estEyeY = (box.top + box.height() * 0.38f) / frameHeight
            landmarks.add(FaceLandmarkPoint(estLeftX.toDouble().coerceIn(0.0, 1.0), estEyeY.toDouble().coerceIn(0.0, 1.0)))
            landmarks.add(FaceLandmarkPoint(estRightX.toDouble().coerceIn(0.0, 1.0), estEyeY.toDouble().coerceIn(0.0, 1.0)))
        }
        val otherTypes = listOf(
            FaceLandmark.NOSE_BASE, FaceLandmark.MOUTH_LEFT,
            FaceLandmark.MOUTH_RIGHT, FaceLandmark.MOUTH_BOTTOM,
        )
        for (type in otherTypes) {
            face.getLandmark(type)?.position?.let {
                landmarks.add(FaceLandmarkPoint((it.x / frameWidth).toDouble().coerceIn(0.0, 1.0), (it.y / frameHeight).toDouble().coerceIn(0.0, 1.0)))
            }
        }

        return FaceDetectionResult(
            faceCount = 1,
            trackingId = face.trackingId,
            boundingBox = normalizedBox,
            landmarks = landmarks,
            yawDegrees = face.headEulerAngleY.toDouble(),
            pitchDegrees = face.headEulerAngleX.toDouble(),
            rollDegrees = face.headEulerAngleZ.toDouble(),
            leftEyeOpenProbability = face.leftEyeOpenProbability?.toDouble(),
            rightEyeOpenProbability = face.rightEyeOpenProbability?.toDouble(),
            smilingProbability = face.smilingProbability?.toDouble(),
        )
    }

    fun close() {
        detector.close()
    }
}
