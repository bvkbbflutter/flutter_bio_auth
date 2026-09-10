import 'biometric_failure_reason.dart';

class FaceEnrollmentResult {
  const FaceEnrollmentResult({
    required this.success,
    required this.userId,
    required this.samplesUsed,
    required this.duration,
    this.failureReason,
  });

  factory FaceEnrollmentResult.fromMap(Map<Object?, Object?> map) {
    return FaceEnrollmentResult(
      success: map['success']! as bool,
      userId: map['userId']! as String,
      samplesUsed: map['samplesUsed']! as int,
      duration: Duration(milliseconds: map['durationMs']! as int),
      failureReason: map['failureReason'] != null
          ? FaceAuthenticationFailureReason.values
              .byName(map['failureReason']! as String)
          : null,
    );
  }

  final bool success;
  final String userId;

  /// Number of good-quality frames aggregated into the stored
  /// template. Always > 1 on success (see README — a template is
  /// never generated from a single frame).
  final int samplesUsed;
  final Duration duration;
  final FaceAuthenticationFailureReason? failureReason;
}
