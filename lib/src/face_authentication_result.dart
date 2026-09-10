import 'biometric_failure_reason.dart';

/// Result of [FaceBiometric.authenticate].
///
/// [authenticated] is only ever true if every check required by the
/// active `FaceAuthenticationMode` passed its configured threshold —
/// see `AuthenticationEngine` on each platform. The individual scores
/// are exposed for UI/telemetry but must never be re-derived into a
/// pass/fail decision in application code; the native
/// `AuthenticationEngine` is the single source of truth for that
/// decision.
class FaceAuthenticationResult {
  const FaceAuthenticationResult({
    required this.authenticated,
    required this.userId,
    required this.similarity,
    required this.livenessScore,
    required this.antiSpoofScore,
    required this.duration,
    this.failureReason,
  });

  factory FaceAuthenticationResult.fromMap(Map<Object?, Object?> map) {
    return FaceAuthenticationResult(
      authenticated: map['authenticated']! as bool,
      userId: map['userId']! as String,
      similarity: (map['similarity']! as num).toDouble(),
      livenessScore: (map['livenessScore']! as num).toDouble(),
      antiSpoofScore: (map['antiSpoofScore']! as num).toDouble(),
      duration: Duration(milliseconds: map['durationMs']! as int),
      failureReason: map['failureReason'] != null
          ? FaceAuthenticationFailureReason.values
              .byName(map['failureReason']! as String)
          : null,
    );
  }

  final bool authenticated;
  final String userId;
  final double similarity;
  final double livenessScore;
  final double antiSpoofScore;
  final Duration duration;
  final FaceAuthenticationFailureReason? failureReason;
}
