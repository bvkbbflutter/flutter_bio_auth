import Foundation

/// CENTER -> turn -> HOLD state machine for turnLeft/turnRight
/// (yaw-based). lookUp/lookDown are declared here for interface
/// parity with Android but always report zero progress on iOS,
/// because Vision does not expose head pitch (see FaceAnalyzer.swift)
/// -- this fails the challenge closed (it will time out) rather than
/// deriving an unreliable pitch proxy and risking a false pass. If you
/// need lookUp/lookDown on iOS, supply pitch from your own model or
/// exclude those two challenges from `FaceBiometricConfig.challenges`
/// on iOS builds.
final class HeadPoseDetector {
    private enum Phase { case waitingCenter, waitingTurn, holding }

    private let challenge: LivenessChallenge
    private let angleThresholdDegrees: Double
    private let neutralAngleDegrees: Double
    private let holdFrameCount: Int
    private var phase: Phase = .waitingCenter
    private var heldFrames = 0

    init(
        challenge: LivenessChallenge, angleThresholdDegrees: Double = 18.0,
        neutralAngleDegrees: Double = 8.0, holdFrameCount: Int = 3
    ) {
        self.challenge = challenge
        self.angleThresholdDegrees = angleThresholdDegrees
        self.neutralAngleDegrees = neutralAngleDegrees
        self.holdFrameCount = holdFrameCount
    }

    func update(yawDegrees: Double?, pitchDegrees: Double?) -> (progress: Double, completed: Bool) {
        let relevantAngle: Double?
        switch challenge {
        case .turnLeft, .turnRight: relevantAngle = yawDegrees
        case .lookUp, .lookDown: relevantAngle = pitchDegrees // always nil on iOS today
        default: relevantAngle = nil
        }
        guard let angle = relevantAngle else { return (progress(for: phase), false) }

        let signedTarget: Double
        switch challenge {
        case .turnLeft: signedTarget = angle
        case .turnRight: signedTarget = -angle
        case .lookUp: signedTarget = angle
        case .lookDown: signedTarget = -angle
        default: signedTarget = 0
        }

        switch phase {
        case .waitingCenter:
            if abs(angle) <= neutralAngleDegrees { phase = .waitingTurn }
        case .waitingTurn:
            if signedTarget >= angleThresholdDegrees {
                heldFrames = 1
                phase = .holding
            }
        case .holding:
            if signedTarget >= angleThresholdDegrees {
                heldFrames += 1
                if heldFrames >= holdFrameCount {
                    reset()
                    return (1.0, true)
                }
            } else {
                phase = .waitingTurn
                heldFrames = 0
            }
        }
        return (progress(for: phase), false)
    }

    private func progress(for phase: Phase) -> Double {
        switch phase {
        case .waitingCenter: return 0.0
        case .waitingTurn: return 0.30
        case .holding: return 0.60 + min(0.40, 0.40 * Double(heldFrames) / Double(holdFrameCount))
        }
    }

    func reset() {
        phase = .waitingCenter
        heldFrames = 0
    }
}

/// moveCloser/moveAway via smoothed face-bounding-box height delta.
/// Mirrors Android's DistanceDetector.
final class DistanceDetector {
    private let challenge: LivenessChallenge
    private let deltaThreshold: Double
    private var baselineHeight: Double?

    init(challenge: LivenessChallenge, deltaThreshold: Double = 0.08) {
        self.challenge = challenge
        self.deltaThreshold = deltaThreshold
    }

    func update(faceHeightFraction: Double?) -> (progress: Double, completed: Bool) {
        guard let height = faceHeightFraction else { return (0.0, false) }
        guard let baseline = baselineHeight else {
            baselineHeight = height
            return (0.0, false)
        }
        let delta = height - baseline
        let relevantDelta = challenge == .moveCloser ? delta : -delta
        let progress = min(1.0, max(0.0, relevantDelta / deltaThreshold))
        if relevantDelta >= deltaThreshold {
            reset()
            return (1.0, true)
        }
        return (progress, false)
    }

    func reset() { baselineHeight = nil }
}
