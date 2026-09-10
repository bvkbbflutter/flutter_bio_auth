package com.vinay.flutter_bio_auth

/**
 * Temporal smile state machine: NEUTRAL -> SMILE -> MAINTAINED across
 * [sustainFrameCount] consecutive frames, driven by [FaceTracker]'s
 * smoothed smiling probability.
 */
class SmileDetector(
    private val smileThreshold: Double = 0.40,
    private val neutralThreshold: Double = 0.30,
    private val sustainFrameCount: Int = 2,
) {
    private var sustainedFrames = 0

    fun update(smilingProbability: Double?): Pair<Double, Boolean> {
        if (smilingProbability == null) return Pair(0.0, false)

        val prob = smilingProbability.coerceIn(0.0, 1.0)
        if (prob >= smileThreshold) {
            sustainedFrames++
            if (sustainedFrames >= sustainFrameCount) {
                reset()
                return Pair(1.0, true)
            }
        } else {
            // Decay sustained frames gently rather than hard-resetting to neutral.
            // This prevents repeated "asking multiple times" when expression fluctuates.
            if (sustainedFrames > 0) sustainedFrames--
        }

        val ratio = (prob / smileThreshold).coerceIn(0.0, 1.0)
        val progress = (ratio * 0.70) + (0.30 * sustainedFrames / sustainFrameCount)
        return Pair(progress.coerceIn(0.0, 0.99), false)
    }

    fun reset() {
        sustainedFrames = 0
    }
}
