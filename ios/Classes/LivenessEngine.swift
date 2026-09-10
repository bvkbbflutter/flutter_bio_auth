import Foundation

/// Builds the ordered challenge list for one session: dedupe
/// preserving first-seen order, then optional shuffle. Mirrors
/// lib/src/challenge_sequencer.dart and Android's ChallengeEngine.kt.
final class ChallengeEngine {
    func buildSequence(pool: [LivenessChallenge], randomize: Bool) -> [LivenessChallenge] {
        guard !pool.isEmpty else { return [] }
        var seen = Set<LivenessChallenge>()
        let deduped = pool.filter { seen.insert($0).inserted }
        return randomize ? deduped.shuffled() : deduped
    }
}

/// Runs one liveness session: sequences challenges, dispatches each
/// frame to the matching detector, and enforces a per-challenge
/// timeout. Mirrors Android's LivenessEngine.kt.
final class LivenessEngine {
    private let sequence: [LivenessChallenge]
    private let challengeTimeoutSeconds: TimeInterval
    private let now: () -> TimeInterval

    private var currentIndex = 0
    private var currentChallengeStartedAt: TimeInterval?
    private var completed: [LivenessChallenge] = []
    private var failedChallenge: LivenessChallenge?

    private let blink = BlinkDetector()
    private let smile = SmileDetector()
    private let turnLeft = HeadPoseDetector(challenge: .turnLeft)
    private let turnRight = HeadPoseDetector(challenge: .turnRight)
    private let lookUp = HeadPoseDetector(challenge: .lookUp)
    private let lookDown = HeadPoseDetector(challenge: .lookDown)
    private let moveCloser = DistanceDetector(challenge: .moveCloser)
    private let moveAway = DistanceDetector(challenge: .moveAway)

    struct FrameOutcome {
        let challenge: LivenessChallenge?
        let progress: Double
        let confidence: Double
        let completed: Bool
        let timedOut: Bool
    }

    init(sequence: [LivenessChallenge], challengeTimeoutMillis: Int64, now: @escaping () -> TimeInterval = { Date().timeIntervalSince1970 }) {
        self.sequence = sequence
        self.challengeTimeoutSeconds = TimeInterval(challengeTimeoutMillis) / 1000.0
        self.now = now
    }

    var currentChallenge: LivenessChallenge? { currentIndex < sequence.count ? sequence[currentIndex] : nil }
    var isFinished: Bool { currentIndex >= sequence.count || failedChallenge != nil }

    func onFrame(_ state: FaceTracker.SmoothedState) -> FrameOutcome? {
        guard let challenge = currentChallenge else { return nil }
        let startedAt = currentChallengeStartedAt ?? { let t = now(); currentChallengeStartedAt = t; return t }()

        if now() - startedAt > challengeTimeoutSeconds {
            failedChallenge = challenge
            return FrameOutcome(challenge: challenge, progress: 0.0, confidence: 0.0, completed: false, timedOut: true)
        }

        let result: (progress: Double, completed: Bool)
        switch challenge {
        case .blink: result = blink.update(leftEyeOpen: state.leftEyeOpenProbability, rightEyeOpen: state.rightEyeOpenProbability)
        case .smile: result = smile.update(smilingProbability: state.smilingProbability)
        case .turnLeft: result = turnLeft.update(yawDegrees: state.yawDegrees, pitchDegrees: state.pitchDegrees)
        case .turnRight: result = turnRight.update(yawDegrees: state.yawDegrees, pitchDegrees: state.pitchDegrees)
        case .lookUp: result = lookUp.update(yawDegrees: state.yawDegrees, pitchDegrees: state.pitchDegrees)
        case .lookDown: result = lookDown.update(yawDegrees: state.yawDegrees, pitchDegrees: state.pitchDegrees)
        case .moveCloser: result = moveCloser.update(faceHeightFraction: state.faceHeightFraction)
        case .moveAway: result = moveAway.update(faceHeightFraction: state.faceHeightFraction)
        }

        if result.completed {
            completed.append(challenge)
            currentIndex += 1
            currentChallengeStartedAt = nil
        }
        return FrameOutcome(challenge: challenge, progress: result.progress, confidence: result.progress, completed: result.completed, timedOut: false)
    }

    func finish() -> LivenessResult {
        let passed = failedChallenge == nil && completed.count == sequence.count && !sequence.isEmpty
        let overallScore = sequence.isEmpty ? 0.0 : Double(completed.count) / Double(sequence.count)
        return LivenessResult(passed: passed, overallScore: overallScore, completedChallenges: completed, failedChallenge: failedChallenge)
    }

    func reset() {
        currentIndex = 0
        currentChallengeStartedAt = nil
        completed.removeAll()
        failedChallenge = nil
        blink.reset(); smile.reset()
        turnLeft.reset(); turnRight.reset(); lookUp.reset(); lookDown.reset()
        moveCloser.reset(); moveAway.reset()
    }
}
