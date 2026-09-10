/// Why the passive anti-spoof engine reached its conclusion. See
/// README "Liveness security" — this is a signal, not a certified
/// presentation-attack-detection verdict.
enum AntiSpoofReason {
  live,
  photo,
  screenReplay,
  videoReplay,
  suspiciousTexture,
  suspiciousMotion,
  lowConfidence,

  /// No anti-spoof model was configured
  /// ([FaceBiometricConfig.antiSpoofModelAssetPath] unset). Callers
  /// must treat this the same as a failed check when anti-spoofing is
  /// required by the active [FaceAuthenticationMode] — never as an
  /// implicit pass.
  modelUnavailable,
  unknown,
}

class AntiSpoofResult {
  const AntiSpoofResult({
    required this.isLive,
    required this.confidence,
    required this.reason,
  });

  factory AntiSpoofResult.fromMap(Map<Object?, Object?> map) {
    return AntiSpoofResult(
      isLive: map['isLive']! as bool,
      confidence: (map['confidence']! as num).toDouble(),
      reason: AntiSpoofReason.values.byName(map['reason']! as String),
    );
  }

  /// Result to use when [FaceBiometricConfig.antiSpoofModelAssetPath]
  /// is not configured. `isLive` is deliberately false: absence of a
  /// model must never be interpreted as a passing anti-spoof check.
  static const AntiSpoofResult unavailable = AntiSpoofResult(
    isLive: false,
    confidence: 0.0,
    reason: AntiSpoofReason.modelUnavailable,
  );

  final bool isLive;
  final double confidence;
  final AntiSpoofReason reason;

  Map<String, Object?> toMap() => <String, Object?>{
        'isLive': isLive,
        'confidence': confidence,
        'reason': reason.name,
      };
}
