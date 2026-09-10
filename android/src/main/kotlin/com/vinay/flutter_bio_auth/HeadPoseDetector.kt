package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.LivenessChallenge
import kotlin.math.abs

/**
 * CENTER -> threshold reached -> HOLD -> back toward CENTER for
 * turnLeft/turnRight/lookUp/lookDown. Uses yaw for left/right, pitch
 * for up/down. A single extreme-angle frame never completes the
 * challenge; the angle must be sustained for [holdFrameCount] frames.
 */
class HeadPoseDetector(
    private val challenge: LivenessChallenge,
    private val angleThresholdDegrees: Double = 14.0,
    private val neutralAngleDegrees: Double = 8.0,
    private val holdFrameCount: Int = 2,
) {
    private enum class Phase { WAITING_CENTER, WAITING_TURN, HOLDING }

    private var phase = Phase.WAITING_CENTER
    private var heldFrames = 0

    fun update(yawDegrees: Double?, pitchDegrees: Double?): Pair<Double, Boolean> {
        val relevantAngle = when (challenge) {
            LivenessChallenge.turnLeft, LivenessChallenge.turnRight -> yawDegrees
            LivenessChallenge.lookUp, LivenessChallenge.lookDown -> pitchDegrees
            else -> null
        } ?: return Pair(progressFor(phase), false)

        // ML Kit convention: positive headEulerAngleY = face turned
        // toward the device's left (i.e. the user's right). Sign
        // mapping below assumes that convention; verify against your
        // device orientation handling in CameraManager if you change
        // camera facing.
        val signedTarget = when (challenge) {
            LivenessChallenge.turnLeft -> relevantAngle
            LivenessChallenge.turnRight -> -relevantAngle
            LivenessChallenge.lookUp -> relevantAngle
            LivenessChallenge.lookDown -> -relevantAngle
            else -> 0.0
        }

        when (phase) {
            Phase.WAITING_CENTER -> {
                if (abs(relevantAngle) <= neutralAngleDegrees) phase = Phase.WAITING_TURN
            }
            Phase.WAITING_TURN -> {
                if (signedTarget >= angleThresholdDegrees) {
                    heldFrames = 1
                    phase = Phase.HOLDING
                }
            }
            Phase.HOLDING -> {
                if (signedTarget >= angleThresholdDegrees) {
                    heldFrames++
                    if (heldFrames >= holdFrameCount) {
                        reset()
                        return Pair(1.0, true)
                    }
                } else {
                    phase = Phase.WAITING_TURN
                    heldFrames = 0
                }
            }
        }
        return Pair(progressFor(phase), false)
    }

    private fun progressFor(phase: Phase): Double = when (phase) {
        Phase.WAITING_CENTER -> 0.0
        Phase.WAITING_TURN -> 0.30
        Phase.HOLDING -> 0.60 + (0.40 * heldFrames / holdFrameCount).coerceAtMost(0.40)
    }

    fun reset() {
        phase = Phase.WAITING_CENTER
        heldFrames = 0
    }
}

/**
 * moveCloser/moveAway: tracks smoothed face-bounding-box height over
 * time and requires a sustained, monotonic-ish change past
 * [deltaThreshold] rather than a single-frame jump (which is usually
 * detector jitter, not real movement).
 */
class DistanceDetector(
    private val challenge: LivenessChallenge,
    private val deltaThreshold: Double = 0.08,
) {
    private var baselineHeight: Double? = null

    fun update(faceHeightFraction: Double?): Pair<Double, Boolean> {
        if (faceHeightFraction == null) return Pair(0.0, false)
        val baseline = baselineHeight ?: run {
            baselineHeight = faceHeightFraction
            return Pair(0.0, false)
        }

        val delta = faceHeightFraction - baseline
        val relevantDelta = if (challenge == LivenessChallenge.moveCloser) delta else -delta
        val progress = (relevantDelta / deltaThreshold).coerceIn(0.0, 1.0)

        if (relevantDelta >= deltaThreshold) {
            reset()
            return Pair(1.0, true)
        }
        return Pair(progress, false)
    }

    fun reset() {
        baselineHeight = null
    }
}
