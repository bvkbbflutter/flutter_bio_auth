import Foundation

/// OPEN -> CLOSED -> OPEN state machine. A single closed-eye frame
/// never counts as a blink. Mirrors BlinkDetector.kt.
final class BlinkDetector {
    private enum Phase { case waitingOpen, waitingClose, waitingReopen }

    private let openThreshold: Double
    private let closedThreshold: Double
    private var phase: Phase = .waitingOpen
    private var minObservedDuringClosedPhase = 1.0

    init(openThreshold: Double = 0.55, closedThreshold: Double = 0.35) {
        self.openThreshold = openThreshold
        self.closedThreshold = closedThreshold
    }

    func update(leftEyeOpen: Double?, rightEyeOpen: Double?) -> (progress: Double, completed: Bool) {
        guard let l = leftEyeOpen, let r = rightEyeOpen else { return (progress(for: phase), false) }
        let eyesOpen = min(l, r)

        switch phase {
        case .waitingOpen:
            if eyesOpen >= openThreshold { phase = .waitingClose }
        case .waitingClose:
            if eyesOpen <= closedThreshold {
                minObservedDuringClosedPhase = eyesOpen
                phase = .waitingReopen
            }
        case .waitingReopen:
            minObservedDuringClosedPhase = min(minObservedDuringClosedPhase, eyesOpen)
            if eyesOpen >= openThreshold {
                let completed = minObservedDuringClosedPhase <= closedThreshold
                reset()
                return (1.0, completed)
            }
        }
        return (progress(for: phase), false)
    }

    private func progress(for phase: Phase) -> Double {
        switch phase {
        case .waitingOpen: return 0.0
        case .waitingClose: return 0.35
        case .waitingReopen: return 0.75
        }
    }

    func reset() {
        phase = .waitingOpen
        minObservedDuringClosedPhase = 1.0
    }
}
