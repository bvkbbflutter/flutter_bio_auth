/// The combination of security layers required for authentication to
/// succeed. See README "Recognition security" / "Liveness security" —
/// none of these modes constitute a certified presentation-attack
/// detection system on their own.
enum FaceAuthenticationMode {
  /// Recognition only. No liveness, no anti-spoof. Weakest mode;
  /// vulnerable to a static photo of the enrolled user. Intended for
  /// low-risk convenience flows only, e.g. re-skinning a UI, not for
  /// anything security-sensitive.
  faceOnly,

  /// Recognition + active liveness challenges (blink/turn/etc). No
  /// passive anti-spoof model.
  faceWithLiveness,

  /// Recognition + active liveness + passive anti-spoof model. The
  /// default. Requires [FaceBiometricConfig.antiSpoofModelAssetPath]
  /// to be configured; if it isn't, authentication fails closed
  /// (returns [BiometricFailureReason.modelUnavailable]) rather than
  /// silently downgrading to [faceWithLiveness].
  faceWithLivenessAndAntiSpoof,
}
