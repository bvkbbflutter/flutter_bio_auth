package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.FaceDetectionResult

/**
 * Applies exponential smoothing across consecutive [FaceDetectionResult]
 * frames so a single noisy frame (motion blur, a half-closed eye
 * during a normal blink between challenges, momentary tracker jitter)
 * can't flip a decision. Every challenge detector and
 * [FaceQualityAnalyzer] reads from here rather than raw per-frame
 * output.
 */
class FaceTracker(private val smoothingFactor: Double = 0.35) {

    private var smoothedYaw: Double? = null
    private var smoothedPitch: Double? = null
    private var smoothedRoll: Double? = null
    private var smoothedLeftEye: Double? = null
    private var smoothedRightEye: Double? = null
    private var smoothedSmile: Double? = null
    private var smoothedFaceHeight: Double? = null

    private var lastTrackingId: Int? = null
    private var consecutiveNoFaceFrames = 0

    val consecutiveMissingFrameThreshold = 8

    data class SmoothedState(
        val yawDegrees: Double?,
        val pitchDegrees: Double?,
        val rollDegrees: Double?,
        val leftEyeOpenProbability: Double?,
        val rightEyeOpenProbability: Double?,
        val smilingProbability: Double?,
        val faceHeightFraction: Double?,
        val trackingContinuous: Boolean,
    )

    fun update(frame: FaceDetectionResult): SmoothedState {
        if (frame.faceCount != 1) {
            consecutiveNoFaceFrames++
            if (consecutiveNoFaceFrames >= consecutiveMissingFrameThreshold) {
                reset()
            }
            return currentState(trackingContinuous = false)
        }
        consecutiveNoFaceFrames = 0

        val trackingContinuous = lastTrackingId != null && lastTrackingId == frame.trackingId
        lastTrackingId = frame.trackingId

        smoothedYaw = ema(smoothedYaw, frame.yawDegrees)
        smoothedPitch = ema(smoothedPitch, frame.pitchDegrees)
        smoothedRoll = ema(smoothedRoll, frame.rollDegrees)
        smoothedLeftEye = emaEye(smoothedLeftEye, frame.leftEyeOpenProbability)
        smoothedRightEye = emaEye(smoothedRightEye, frame.rightEyeOpenProbability)
        smoothedSmile = ema(smoothedSmile, frame.smilingProbability, factor = 0.55)
        smoothedFaceHeight = ema(smoothedFaceHeight, frame.boundingBox?.height)

        return currentState(trackingContinuous)
    }

    private fun currentState(trackingContinuous: Boolean) = SmoothedState(
        yawDegrees = smoothedYaw,
        pitchDegrees = smoothedPitch,
        rollDegrees = smoothedRoll,
        leftEyeOpenProbability = smoothedLeftEye,
        rightEyeOpenProbability = smoothedRightEye,
        smilingProbability = smoothedSmile,
        faceHeightFraction = smoothedFaceHeight,
        trackingContinuous = trackingContinuous,
    )

    private fun ema(previous: Double?, next: Double?, factor: Double = smoothingFactor): Double? {
        if (next == null) return previous
        if (previous == null) return next
        return previous + factor * (next - previous)
    }

    private fun emaEye(previous: Double?, next: Double?): Double? {
        if (next == null) return previous
        if (previous == null) return next
        // Asymmetric response: track fast downward drops (blinks) immediately so a 150ms
        // blink is never smoothed away, while smoothly tracking eyes reopening.
        val factor = if (next < previous) 0.85 else 0.50
        return previous + factor * (next - previous)
    }

    fun reset() {
        smoothedYaw = null; smoothedPitch = null; smoothedRoll = null
        smoothedLeftEye = null; smoothedRightEye = null; smoothedSmile = null
        smoothedFaceHeight = null; lastTrackingId = null; consecutiveNoFaceFrames = 0
    }
}
