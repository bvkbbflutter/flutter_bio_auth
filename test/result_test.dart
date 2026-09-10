import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceMatchResult', () {
    test('fromMap parses a passing match', () {
      final FaceMatchResult result = FaceMatchResult.fromMap(<Object?, Object?>{
        'isMatch': true,
        'similarity': 0.91,
        'threshold': 0.82,
      });
      expect(result.isMatch, isTrue);
      expect(result.similarity, 0.91);
      expect(result.threshold, 0.82);
    });
  });

  group('FaceEnrollmentResult', () {
    test('fromMap parses a failure with reason', () {
      final FaceEnrollmentResult result = FaceEnrollmentResult.fromMap(
        <Object?, Object?>{
          'success': false,
          'userId': 'user_001',
          'samplesUsed': 0,
          'durationMs': 1200,
          'failureReason': 'poorFaceQuality',
        },
      );
      expect(result.success, isFalse);
      expect(
        result.failureReason,
        FaceAuthenticationFailureReason.poorFaceQuality,
      );
    });

    test('fromMap parses a success with no failure reason', () {
      final FaceEnrollmentResult result = FaceEnrollmentResult.fromMap(
        <Object?, Object?>{
          'success': true,
          'userId': 'user_001',
          'samplesUsed': 5,
          'durationMs': 4300,
          'failureReason': null,
        },
      );
      expect(result.success, isTrue);
      expect(result.samplesUsed, 5);
      expect(result.failureReason, isNull);
    });
  });

  group('AntiSpoofResult', () {
    test('unavailable constant reports not-live with modelUnavailable', () {
      expect(AntiSpoofResult.unavailable.isLive, isFalse);
      expect(
        AntiSpoofResult.unavailable.reason,
        AntiSpoofReason.modelUnavailable,
      );
    });
  });

  group('BiometricError', () {
    test('toString includes the error code name', () {
      const BiometricError error = BiometricError(
        FaceBiometricErrorCode.faceMismatch,
        'Face does not match the enrolled template.',
      );
      expect(error.toString(), contains('faceMismatch'));
    });
  });
}
