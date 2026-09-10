import Foundation

/// Exponential smoothing across consecutive frames so a single noisy
/// frame can't flip a liveness/quality decision. Mirrors
/// FaceTracker.kt exactly.
final class FaceTracker {
    private let smoothingFactor: Double
    private var smoothedYaw: Double?
    private var smoothedPitch: Double?
    private var smoothedRoll: Double?
    private var smoothedLeftEye: Double?
    private var smoothedRightEye: Double?
    private var smoothedSmile: Double?
    private var smoothedFaceHeight: Double?
    private var lastTrackingId: Int?
    private var consecutiveNoFaceFrames = 0
    private let consecutiveMissingFrameThreshold = 8

    struct SmoothedState {
        let yawDegrees: Double?
        let pitchDegrees: Double?
        let rollDegrees: Double?
        let leftEyeOpenProbability: Double?
        let rightEyeOpenProbability: Double?
        let smilingProbability: Double?
        let faceHeightFraction: Double?
        let trackingContinuous: Bool
    }

    init(smoothingFactor: Double = 0.35) {
        self.smoothingFactor = smoothingFactor
    }

    func update(_ frame: FaceDetectionResult) -> SmoothedState {
        guard frame.faceCount == 1 else {
            consecutiveNoFaceFrames += 1
            if consecutiveNoFaceFrames >= consecutiveMissingFrameThreshold { reset() }
            return currentState(trackingContinuous: false)
        }
        consecutiveNoFaceFrames = 0

        let trackingContinuous = lastTrackingId != nil && lastTrackingId == frame.trackingId
        lastTrackingId = frame.trackingId

        smoothedYaw = ema(smoothedYaw, frame.yawDegrees)
        smoothedPitch = ema(smoothedPitch, frame.pitchDegrees)
        smoothedRoll = ema(smoothedRoll, frame.rollDegrees)
        smoothedLeftEye = ema(smoothedLeftEye, frame.leftEyeOpenProbability)
        smoothedRightEye = ema(smoothedRightEye, frame.rightEyeOpenProbability)
        smoothedSmile = ema(smoothedSmile, frame.smilingProbability)
        smoothedFaceHeight = ema(smoothedFaceHeight, frame.boundingBox?.height)

        return currentState(trackingContinuous: trackingContinuous)
    }

    private func currentState(trackingContinuous: Bool) -> SmoothedState {
        SmoothedState(
            yawDegrees: smoothedYaw, pitchDegrees: smoothedPitch, rollDegrees: smoothedRoll,
            leftEyeOpenProbability: smoothedLeftEye, rightEyeOpenProbability: smoothedRightEye,
            smilingProbability: smoothedSmile, faceHeightFraction: smoothedFaceHeight,
            trackingContinuous: trackingContinuous
        )
    }

    private func ema(_ previous: Double?, _ next: Double?) -> Double? {
        guard let next = next else { return previous }
        guard let previous = previous else { return next }
        return previous + smoothingFactor * (next - previous)
    }

    func reset() {
        smoothedYaw = nil; smoothedPitch = nil; smoothedRoll = nil
        smoothedLeftEye = nil; smoothedRightEye = nil; smoothedSmile = nil
        smoothedFaceHeight = nil; lastTrackingId = nil; consecutiveNoFaceFrames = 0
    }
}
