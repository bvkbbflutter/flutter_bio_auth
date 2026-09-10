package com.vinay.flutter_bio_auth

import android.graphics.Bitmap
import android.graphics.Matrix
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import com.vinay.flutter_bio_auth.model.FaceDetectionResult
import kotlin.math.atan2

/**
 * Produces the exact same preprocessing pipeline for a detected face
 * regardless of call site (enrollment / authentication / compare()):
 *
 *   detected face -> landmarks -> eye-based rotation correction ->
 *   crop -> resize -> normalize -> tensor
 *
 * Using one shared implementation is what makes embeddings generated
 * at enrollment time comparable to embeddings generated at
 * authentication time -- see README "Face alignment".
 */
class FaceAlignment(private val outputSize: Int = 112) {

    /**
     * @param sourceBitmap the full camera frame (or a still image for
     *   `compare()`), already rotated to upright orientation.
     * @param detection the corresponding single-face detection result,
     *   with bounding box and landmarks in the SAME pixel space as
     *   [sourceBitmap] (i.e. not yet normalized to [0,1] -- callers in
     *   this codebase pass the pre-normalization detection through a
     *   pixel-space variant; see CameraManager for the conversion
     *   point).
     * @param leftEyePx left eye position in [sourceBitmap] pixel space.
     * @param rightEyePx right eye position in [sourceBitmap] pixel
     *   space.
     */
    fun alignAndNormalize(
        sourceBitmap: Bitmap,
        boxLeft: Int, boxTop: Int, boxWidth: Int, boxHeight: Int,
        leftEyePx: Pair<Float, Float>,
        rightEyePx: Pair<Float, Float>,
    ): FloatArray {
        if (boxWidth <= 0 || boxHeight <= 0) {
            throw BiometricException(
                FaceBiometricErrorCode.embeddingGenerationFailed,
                "Cannot align a face with a non-positive bounding box.",
            )
        }

        // 1. Order eyes by X-coordinate in image coordinate space:
        // imgLeftEye is viewer's left (smaller x); imgRightEye is viewer's right (larger x).
        val (imgLeftEye, imgRightEye) = if (leftEyePx.first < rightEyePx.first) {
            Pair(leftEyePx, rightEyePx)
        } else {
            Pair(rightEyePx, leftEyePx)
        }

        val dx = (imgRightEye.first - imgLeftEye.first).toDouble()
        val dy = (imgRightEye.second - imgLeftEye.second).toDouble()
        var angleDegrees = Math.toDegrees(atan2(dy, dx))
        if (kotlin.math.abs(angleDegrees) > 45.0) {
            angleDegrees = 0.0
        }

        // 2. Crop face region with a 15% context margin (expected by MobileFaceNet/ArcFace).
        val marginX = (boxWidth * 0.15f).toInt()
        val marginY = (boxHeight * 0.15f).toInt()
        val cropLeft = (boxLeft - marginX).coerceIn(0, sourceBitmap.width - 1)
        val cropTop = (boxTop - marginY).coerceIn(0, sourceBitmap.height - 1)
        val cropRight = (boxLeft + boxWidth + marginX).coerceIn(cropLeft + 1, sourceBitmap.width)
        val cropBottom = (boxTop + boxHeight + marginY).coerceIn(cropTop + 1, sourceBitmap.height)
        val cropWidth = cropRight - cropLeft
        val cropHeight = cropBottom - cropTop

        val faceCrop = Bitmap.createBitmap(sourceBitmap, cropLeft, cropTop, cropWidth, cropHeight)

        // 3. Rotate face crop so eye line is level (only when meaningful tilt exists, avoiding artificial edge distortion).
        val alignedBitmap = if (kotlin.math.abs(angleDegrees) in 3.0..35.0) {
            val rotationMatrix = Matrix().apply {
                postRotate(-angleDegrees.toFloat(), faceCrop.width / 2f, faceCrop.height / 2f)
            }
            val rotated = Bitmap.createBitmap(faceCrop, 0, 0, faceCrop.width, faceCrop.height, rotationMatrix, true)
            if (rotated != faceCrop) {
                faceCrop.recycle()
            }
            rotated
        } else {
            faceCrop
        }

        // 4. Resize to 112x112.
        val resized = Bitmap.createScaledBitmap(alignedBitmap, outputSize, outputSize, true)
        if (resized != alignedBitmap) {
            alignedBitmap.recycle()
        }

        // 5. Normalize to [-1, 1] per channel, HWC RGB float tensor.
        val tensor = normalizeToTensor(resized)
        resized.recycle()
        return tensor
    }

    private fun normalizeToTensor(bitmap: Bitmap): FloatArray {
        val pixels = IntArray(outputSize * outputSize)
        bitmap.getPixels(pixels, 0, outputSize, 0, 0, outputSize, outputSize)

        val tensor = FloatArray(outputSize * outputSize * 3)
        var i = 0
        for (pixel in pixels) {
            val r = (pixel shr 16 and 0xFF)
            val g = (pixel shr 8 and 0xFF)
            val b = (pixel and 0xFF)
            tensor[i++] = (r - 127.5f) / 127.5f
            tensor[i++] = (g - 127.5f) / 127.5f
            tensor[i++] = (b - 127.5f) / 127.5f
        }
        return tensor
    }

    /** Rough sharpness/brightness estimate reused by FaceQualityAnalyzer
     *  callers. Uses a sampled thumbnail for fast computation on live frames. */
    fun estimateSharpnessAndBrightness(bitmap: Bitmap): Pair<Double, Double> {
        val sampleBitmap = if (bitmap.width > 160 || bitmap.height > 160) {
            Bitmap.createScaledBitmap(bitmap, 128, 128, true)
        } else {
            bitmap
        }
        val w = sampleBitmap.width
        val h = sampleBitmap.height
        val luma = DoubleArray(w * h)
        val pixels = IntArray(w * h)
        sampleBitmap.getPixels(pixels, 0, w, 0, 0, w, h)
        var sum = 0.0
        for (idx in pixels.indices) {
            val p = pixels[idx]
            val r = (p shr 16 and 0xFF)
            val g = (p shr 8 and 0xFF)
            val b = (p and 0xFF)
            val y = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            luma[idx] = y
            sum += y
        }
        val mean = sum / luma.size

        // Simple discrete Laplacian for a blur proxy.
        var lapSumSq = 0.0
        var count = 0
        for (y in 1 until h - 1) {
            for (x in 1 until w - 1) {
                val idx = y * w + x
                val lap = -4 * luma[idx] + luma[idx - 1] + luma[idx + 1] + luma[idx - w] + luma[idx + w]
                lapSumSq += lap * lap
                count++
            }
        }
        if (sampleBitmap != bitmap) {
            sampleBitmap.recycle()
        }
        val variance = if (count > 0) (lapSumSq / count) * 255.0 * 255.0 / 4.0 else 0.0
        return Pair(variance, mean)
    }
}
