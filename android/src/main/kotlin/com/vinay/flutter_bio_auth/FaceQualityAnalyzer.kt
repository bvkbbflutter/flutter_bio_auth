package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import com.vinay.flutter_bio_auth.model.FaceQualityResult
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Computes [FaceQualityResult] from geometry alone (bounding box size
 * / position, head pose) plus a luma-based brightness/blur estimate
 * passed in by the caller. Entirely deterministic; no ML model
 * involved, so this always works even when no embedding/anti-spoof
 * model is configured.
 */
class FaceQualityAnalyzer(
    private val minimumFaceSize: Double,
    private val maximumFaceSize: Double,
    private val requireCentered: Boolean,
    private val maxFrontalYawDegrees: Double = 25.0,
    private val maxFrontalPitchDegrees: Double = 25.0,
    private val centeringTolerance: Double = 0.25,
    private val minAcceptableBrightness: Double = 0.12,
    private val maxAcceptableBrightness: Double = 0.95,
    private val blurVarianceThreshold: Double = 12.0,
) {

    /**
     * @param laplacianVariance a sharpness proxy computed by the
     *   caller from the luma plane of the face crop (variance of a
     *   Laplacian filter response -- low variance means a flat, blurry
     *   image). Passed in rather than computed here so this class
     *   stays free of Android Bitmap/YUV plumbing and is trivially
     *   unit-testable.
     * @param meanBrightness mean normalized luma [0,1] of the face
     *   crop.
     */
    fun analyze(
        detection: FaceDetectionResult,
        laplacianVariance: Double,
        meanBrightness: Double,
    ): FaceQualityResult {
        val box = detection.boundingBox
        val faceHeight = box?.height ?: 0.0

        val isTooSmall = faceHeight < minimumFaceSize
        val isTooLarge = faceHeight > maximumFaceSize

        val isCentered = if (!requireCentered || box == null) {
            true
        } else {
            val centerX = box.left + box.width / 2.0
            val centerY = box.top + box.height / 2.0
            abs(centerX - 0.5) <= centeringTolerance && abs(centerY - 0.5) <= centeringTolerance
        }

        val isFrontal = (detection.yawDegrees?.let { abs(it) <= maxFrontalYawDegrees } ?: false) &&
            (detection.pitchDegrees?.let { abs(it) <= maxFrontalPitchDegrees } ?: false)

        val isBlurry = laplacianVariance < blurVarianceThreshold
        val brightnessOk = meanBrightness in minAcceptableBrightness..maxAcceptableBrightness

        val sizeScore = when {
            isTooSmall || isTooLarge -> 0.0
            else -> 1.0
        }
        val centerScore = if (isCentered) 1.0 else 0.3
        val frontalScore = if (isFrontal) 1.0 else 0.3
        val blurScore = min(1.0, max(0.0, laplacianVariance / (blurVarianceThreshold * 3)))
        val brightnessScore = if (brightnessOk) 1.0 else 0.4

        val overall = (sizeScore * 0.30) + (centerScore * 0.15) + (frontalScore * 0.20) +
            (blurScore * 0.20) + (brightnessScore * 0.15)

        return FaceQualityResult(
            overallScore = overall.coerceIn(0.0, 1.0),
            isBlurry = isBlurry,
            isTooSmall = isTooSmall,
            isTooLarge = isTooLarge,
            isCentered = isCentered,
            isFrontal = isFrontal,
            brightness = meanBrightness,
        )
    }
}
