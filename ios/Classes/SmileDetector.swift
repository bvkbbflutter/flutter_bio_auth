import Foundation

/// NEUTRAL -> SMILE -> MAINTAINED across `sustainFrameCount` frames.
/// Mirrors SmileDetector.kt.
final class SmileDetector {
    private enum Phase { case waitingNeutral, waitingSmile, sustaining }

    private let smileThreshold: Double
    private let neutralThreshold: Double
    private let sustainFrameCount: Int
    private var phase: Phase = .waitingNeutral
    private var sustainedFrames = 0

    init(smileThreshold: Double = 0.60, neutralThreshold: Double = 0.35, sustainFrameCount: Int = 4) {
        self.smileThreshold = smileThreshold
        self.neutralThreshold = neutralThreshold
        self.sustainFrameCount = sustainFrameCount
    }

    func update(smilingProbability: Double?) -> (progress: Double, completed: Bool) {
        guard let p = smilingProbability else { return (progress(for: phase), false) }

        switch phase {
        case .waitingNeutral:
            if p <= neutralThreshold { phase = .waitingSmile }
        case .waitingSmile:
            if p >= smileThreshold {
                sustainedFrames = 1
                phase = .sustaining
            }
        case .sustaining:
            if p >= smileThreshold {
                sustainedFrames += 1
                if sustainedFrames >= sustainFrameCount {
                    reset()
                    return (1.0, true)
                }
            } else {
                phase = .waitingNeutral
                sustainedFrames = 0
            }
        }
        return (progress(for: phase), false)
    }

    private func progress(for phase: Phase) -> Double {
        switch phase {
        case .waitingNeutral: return 0.0
        case .waitingSmile: return 0.30
        case .sustaining: return 0.60 + min(0.40, 0.40 * Double(sustainedFrames) / Double(sustainFrameCount))
        }
    }

    func reset() {
        phase = .waitingNeutral
        sustainedFrames = 0
    }
}
