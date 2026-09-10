import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceBiometricConfig.validate', () {
    test('accepts the default configuration', () {
      expect(() => const FaceBiometricConfig().validate(), returnsNormally);
    });

    test('rejects out-of-range recognitionThreshold', () {
      expect(
        () => const FaceBiometricConfig(recognitionThreshold: 1.5).validate(),
        throwsArgumentError,
      );
    });

    test('rejects negative threshold', () {
      expect(
        () => const FaceBiometricConfig(livenessThreshold: -0.1).validate(),
        throwsArgumentError,
      );
    });

    test('rejects minimumFaceSize >= maximumFaceSize', () {
      expect(
        () => const FaceBiometricConfig(
          minimumFaceSize: 0.5,
          maximumFaceSize: 0.5,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects zero session timeout', () {
      expect(
        () => const FaceBiometricConfig(
          sessionTimeout: Duration.zero,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects a session timeout too short for the challenge set', () {
      expect(
        () => const FaceBiometricConfig(
          sessionTimeout: Duration(seconds: 2),
          challengeTimeout: Duration(seconds: 8),
          challenges: <LivenessChallenge>[
            LivenessChallenge.blink,
            LivenessChallenge.turnLeft,
            LivenessChallenge.turnRight,
          ],
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects enableLiveness=true with an empty challenge list', () {
      expect(
        () => const FaceBiometricConfig(
          challenges: <LivenessChallenge>[],
        ).validate(),
        throwsArgumentError,
      );
    });

    test(
      'rejects faceWithLivenessAndAntiSpoof mode when anti-spoof disabled',
      () {
        expect(
          () => const FaceBiometricConfig(
            enableAntiSpoofing: false,
          ).validate(),
          throwsArgumentError,
        );
      },
    );

    test('rejects a mode requiring liveness when liveness is disabled', () {
      expect(
        () => const FaceBiometricConfig(
          enableLiveness: false,
          enableAntiSpoofing: false,
          authenticationMode: FaceAuthenticationMode.faceWithLiveness,
        ).validate(),
        throwsArgumentError,
      );
    });

    test('faceOnly mode does not require liveness or anti-spoof', () {
      expect(
        () => const FaceBiometricConfig(
          enableLiveness: false,
          enableAntiSpoofing: false,
          authenticationMode: FaceAuthenticationMode.faceOnly,
        ).validate(),
        returnsNormally,
      );
    });

    test('copyWith overrides only the specified fields', () {
      const FaceBiometricConfig base = FaceBiometricConfig();
      final FaceBiometricConfig updated = base.copyWith(
        recognitionThreshold: 0.9,
      );
      expect(updated.recognitionThreshold, 0.9);
      expect(updated.livenessThreshold, base.livenessThreshold);
    });
  });
}
