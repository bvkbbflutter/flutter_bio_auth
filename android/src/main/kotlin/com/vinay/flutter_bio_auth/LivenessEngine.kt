package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.LivenessChallenge
import com.vinay.flutter_bio_auth.model.LivenessResult

/**
 * Runs one liveness session: a sequence of challenges built by
 * [ChallengeEngine], each driven by the matching temporal detector,
 * each with its own timeout. Never marks a challenge complete from a
 * single frame -- that guarantee lives in the individual detectors
 * ([BlinkDetector], [SmileDetector], [HeadPoseDetector],
 * [DistanceDetector]); this class only sequences and times them.
 */
class LivenessEngine(
    private val sequence: List<LivenessChallenge>,
    private val challengeTimeoutMillis: Long,
    private val nowMillis: () -> Long = { System.currentTimeMillis() },
) {
    private var currentIndex = 0
    private var currentChallengeStartedAt: Long? = null
    private val completed = mutableListOf<LivenessChallenge>()
    private var failedChallenge: LivenessChallenge? = null

    private val blink = BlinkDetector()
    private val smile = SmileDetector()
    private val turnLeft = HeadPoseDetector(LivenessChallenge.turnLeft)
    private val turnRight = HeadPoseDetector(LivenessChallenge.turnRight)
    private val lookUp = HeadPoseDetector(LivenessChallenge.lookUp)
    private val lookDown = HeadPoseDetector(LivenessChallenge.lookDown)
    private val moveCloser = DistanceDetector(LivenessChallenge.moveCloser)
    private val moveAway = DistanceDetector(LivenessChallenge.moveAway)

    val currentChallenge: LivenessChallenge?
        get() = sequence.getOrNull(currentIndex)

    val isFinished: Boolean
        get() = currentIndex >= sequence.size || failedChallenge != null

    data class FrameOutcome(
        val challenge: LivenessChallenge?,
        val progress: Double,
        val confidence: Double,
        val completed: Boolean,
        val timedOut: Boolean,
    )

    /** Feed one smoothed tracker frame. Returns null once
     *  [isFinished] is true -- call [finish] to get the aggregate
     *  result at that point. */
    fun onFrame(state: FaceTracker.SmoothedState): FrameOutcome? {
        val challenge = currentChallenge ?: return null
        val startedAt = currentChallengeStartedAt ?: nowMillis().also { currentChallengeStartedAt = it }

        val isOverChallengeTimeout = nowMillis() - startedAt > challengeTimeoutMillis

        val (progress, justCompleted) = when (challenge) {
            LivenessChallenge.blink -> blink.update(state.leftEyeOpenProbability, state.rightEyeOpenProbability)
            LivenessChallenge.smile -> smile.update(state.smilingProbability)
            LivenessChallenge.turnLeft -> turnLeft.update(state.yawDegrees, state.pitchDegrees)
            LivenessChallenge.turnRight -> turnRight.update(state.yawDegrees, state.pitchDegrees)
            LivenessChallenge.lookUp -> lookUp.update(state.yawDegrees, state.pitchDegrees)
            LivenessChallenge.lookDown -> lookDown.update(state.yawDegrees, state.pitchDegrees)
            LivenessChallenge.moveCloser -> moveCloser.update(state.faceHeightFraction)
            LivenessChallenge.moveAway -> moveAway.update(state.faceHeightFraction)
        }

        if (justCompleted) {
            completed.add(challenge)
            currentIndex++
            currentChallengeStartedAt = null
            failedChallenge = null
            return FrameOutcome(challenge, progress, progress, completed = true, timedOut = false)
        }

        return FrameOutcome(challenge, progress, progress, completed = false, timedOut = isOverChallengeTimeout)
    }

    fun finish(): LivenessResult {
        val passed = completed.size == sequence.size && sequence.isNotEmpty()
        val overallScore = if (sequence.isEmpty()) 0.0 else completed.size.toDouble() / sequence.size
        return LivenessResult(
            passed = passed,
            overallScore = overallScore,
            completedChallenges = completed.toList(),
            failedChallenge = if (passed) null else (failedChallenge ?: currentChallenge),
        )
    }

    fun reset() {
        currentIndex = 0
        currentChallengeStartedAt = null
        completed.clear()
        failedChallenge = null
        blink.reset(); smile.reset()
        turnLeft.reset(); turnRight.reset(); lookUp.reset(); lookDown.reset()
        moveCloser.reset(); moveAway.reset()
    }
}
