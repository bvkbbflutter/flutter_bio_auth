import Foundation

/// The single place a pass/fail authentication decision is made.
/// Explicit AND-ed gates, not an opaque weighted score -- mirrors
/// AuthenticationEngine.kt exactly.
final class AuthenticationEngine {
    private let recognitionThreshold: Double
    private let livenessThreshold: Double
    private let antiSpoofThreshold: Double
    private let requireLiveness: Bool
    private let requireAntiSpoof: Bool

    struct Decision {
        let authenticated: Bool
        let similarity: Double
        let livenessScore: Double
        let antiSpoofScore: Double
        let failureReason: FaceAuthenticationFailureReason?
    }

    init(
        recognitionThreshold: Double, livenessThreshold: Double, antiSpoofThreshold: Double,
        requireLiveness: Bool, requireAntiSpoof: Bool
    ) {
        self.recognitionThreshold = recognitionThreshold
        self.livenessThreshold = livenessThreshold
        self.antiSpoofThreshold = antiSpoofThreshold
        self.requireLiveness = requireLiveness
        self.requireAntiSpoof = requireAntiSpoof
    }

    func decide(
        similarity: Double, livenessPassed: Bool, livenessScore: Double, antiSpoofResult: AntiSpoofResult
    ) -> Decision {
        if similarity < recognitionThreshold {
            return Decision(authenticated: false, similarity: similarity, livenessScore: livenessScore, antiSpoofScore: antiSpoofResult.confidence, failureReason: .faceMismatch)
        }
        if requireLiveness {
            if !livenessPassed || livenessScore < livenessThreshold {
                return Decision(authenticated: false, similarity: similarity, livenessScore: livenessScore, antiSpoofScore: antiSpoofResult.confidence, failureReason: .livenessFailed)
            }
        }
        if requireAntiSpoof {
            if antiSpoofResult.reason == .modelUnavailable {
                return Decision(authenticated: false, similarity: similarity, livenessScore: livenessScore, antiSpoofScore: antiSpoofResult.confidence, failureReason: .modelUnavailable)
            }
            if !antiSpoofResult.isLive || antiSpoofResult.confidence < antiSpoofThreshold {
                return Decision(authenticated: false, similarity: similarity, livenessScore: livenessScore, antiSpoofScore: antiSpoofResult.confidence, failureReason: .antiSpoofFailed)
            }
        }
        return Decision(authenticated: true, similarity: similarity, livenessScore: livenessScore, antiSpoofScore: antiSpoofResult.confidence, failureReason: nil)
    }
}
