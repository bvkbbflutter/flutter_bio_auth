package com.vinay.flutter_bio_auth

/**
 * Temporal blink state machine driven by [FaceTracker]'s smoothed
 * eye-open probabilities. Requires OPEN -> CLOSED -> OPEN across
 * distinct frames; a single closed-eye frame never counts as a blink.
 */
class BlinkDetector(
    private val openThreshold: Double = 0.50,
    private val closedThreshold: Double = 0.38,
) {
    private enum class Phase { WAITING_OPEN, WAITING_CLOSE, WAITING_REOPEN }

    private var phase = Phase.WAITING_OPEN
    private var minObservedDuringClosedPhase = 1.0

    /** Returns progress in [0,1] and whether the blink just completed
     *  on this update. */
    fun update(leftEyeOpen: Double?, rightEyeOpen: Double?): Pair<Double, Boolean> {
        if (leftEyeOpen == null || rightEyeOpen == null) return Pair(progressFor(phase), false)
        val eyesOpen = minOf(leftEyeOpen, rightEyeOpen)

        when (phase) {
            Phase.WAITING_OPEN -> {
                if (eyesOpen >= openThreshold) phase = Phase.WAITING_CLOSE
            }
            Phase.WAITING_CLOSE -> {
                if (eyesOpen <= closedThreshold) {
                    minObservedDuringClosedPhase = eyesOpen
                    phase = Phase.WAITING_REOPEN
                }
            }
            Phase.WAITING_REOPEN -> {
                minObservedDuringClosedPhase = minOf(minObservedDuringClosedPhase, eyesOpen)
                if (eyesOpen >= openThreshold) {
                    val completed = minObservedDuringClosedPhase <= closedThreshold
                    reset()
                    return Pair(1.0, completed)
                }
            }
        }
        return Pair(progressFor(phase), false)
    }

    private fun progressFor(phase: Phase): Double = when (phase) {
        Phase.WAITING_OPEN -> 0.0
        Phase.WAITING_CLOSE -> 0.35
        Phase.WAITING_REOPEN -> 0.75
    }

    fun reset() {
        phase = Phase.WAITING_OPEN
        minObservedDuringClosedPhase = 1.0
    }
}
