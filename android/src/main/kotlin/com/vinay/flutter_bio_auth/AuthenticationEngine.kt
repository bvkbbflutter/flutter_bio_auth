package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.AntiSpoofReason
import com.vinay.flutter_bio_auth.model.AntiSpoofResult
import com.vinay.flutter_bio_auth.model.FaceAuthenticationFailureReason

/**
 * The single place a "pass/fail" authentication decision is made.
 *
 * Deliberately uses explicit AND-ed gates rather than a single
 * opaque weighted score (see README "Final authentication decision"):
 * each layer either meets its own configured threshold or it doesn't,
 * and the whole authentication fails on the first one that doesn't.
 * This keeps the security logic auditable at a glance.
 */
class AuthenticationEngine(
    private val recognitionThreshold: Double,
    private val livenessThreshold: Double,
    private val antiSpoofThreshold: Double,
    private val requireLiveness: Boolean,
    private val requireAntiSpoof: Boolean,
) {

    data class Decision(
        val authenticated: Boolean,
        val similarity: Double,
        val livenessScore: Double,
        val antiSpoofScore: Double,
        val failureReason: FaceAuthenticationFailureReason?,
    )

    /**
     * @param similarity result of [FaceMatcher.cosineSimilarity]
     *   between the live embedding and the decrypted enrolled
     *   template. Pass 0.0 (never a fabricated passing value) if the
     *   embedding could not be generated.
     * @param livenessPassed result of [LivenessEngine.finish]; ignored
     *   if [requireLiveness] is false.
     * @param antiSpoofResult result of the configured
     *   [AntiSpoofEngine]; ignored if [requireAntiSpoof] is false. If
     *   [requireAntiSpoof] is true and this is
     *   [AntiSpoofResult.UNAVAILABLE], authentication fails closed --
     *   it is never treated as a pass.
     */
    fun decide(
        similarity: Double,
        livenessPassed: Boolean,
        livenessScore: Double,
        antiSpoofResult: AntiSpoofResult,
    ): Decision {
        if (similarity < recognitionThreshold) {
            return Decision(false, similarity, livenessScore, antiSpoofResult.confidence, FaceAuthenticationFailureReason.faceMismatch)
        }

        if (requireLiveness) {
            if (!livenessPassed || livenessScore < livenessThreshold) {
                return Decision(false, similarity, livenessScore, antiSpoofResult.confidence, FaceAuthenticationFailureReason.livenessFailed)
            }
        }

        if (requireAntiSpoof) {
            if (antiSpoofResult.reason == AntiSpoofReason.modelUnavailable) {
                return Decision(
                    false, similarity, livenessScore, antiSpoofResult.confidence,
                    FaceAuthenticationFailureReason.modelUnavailable,
                )
            }
            if (!antiSpoofResult.isLive || antiSpoofResult.confidence < antiSpoofThreshold) {
                return Decision(false, similarity, livenessScore, antiSpoofResult.confidence, FaceAuthenticationFailureReason.antiSpoofFailed)
            }
        }

        return Decision(true, similarity, livenessScore, antiSpoofResult.confidence, null)
    }
}
