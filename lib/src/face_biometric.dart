import 'dart:typed_data';

import 'biometric_error.dart';
import 'device_auth_type.dart';
import 'face_authentication_result.dart';
import 'face_biometric_config.dart';
import 'face_biometric_state.dart';
import 'face_enrollment_result.dart';
import 'face_match_result.dart';
import 'liveness_challenge.dart';
import 'liveness_state.dart';
import 'platform/face_biometric_platform.dart';

/// Static, stateless-from-the-caller's-perspective entry point for
/// enrollment and 1:1 authentication.
///
/// For a session with observable progress (liveness challenge state,
/// camera preview, retry/dispose lifecycle), use
/// [FaceBiometricController] instead — this class is a thin
/// convenience wrapper around it for simple call sites.
class FaceBiometric {
  FaceBiometric._();

  static bool _initialized = false;

  /// Must be called once before any other method. Validates [config]
  /// (throws [ArgumentError] on invalid values) and initializes native
  /// camera/ML resources.
  static Future<void> initialize({
    FaceBiometricConfig config = const FaceBiometricConfig(),
  }) async {
    config.validate();
    await FaceBiometricPlatform.instance.initialize(config);
    _initialized = true;
  }

  static void _checkInitialized() {
    if (!_initialized) {
      throw const BiometricError(
        FaceBiometricErrorCode.notInitialized,
        'FaceBiometric.initialize() must be called before use.',
      );
    }
  }

  /// Global stream of coarse session states.
  static Stream<FaceBiometricState> get stateStream =>
      FaceBiometricPlatform.instance.stateStream;

  /// Global stream of real-time active liveness challenge progress.
  static Stream<LivenessChallengeProgress> get challengeProgressStream =>
      FaceBiometricPlatform.instance.challengeProgressStream;

  /// Runs the full enrollment flow (camera → face quality → liveness →
  /// multi-frame embedding aggregation → encryption → storage) for
  /// [userId]. Presents its own native UI/camera session.
  static Future<FaceEnrollmentResult> enroll({required String userId}) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.enroll(userId: userId);
  }

  /// Runs the full 1:1 authentication flow for [userId] against their
  /// previously enrolled template.
  static Future<FaceAuthenticationResult> authenticate({
    required String userId,
  }) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.authenticate(userId: userId);
  }

  /// Runs standalone active liveness verification without requiring any AI
  /// face recognition model. Tests active challenges (blink, smile, head turns)
  /// and returns a [LivenessResult].
  static Future<LivenessResult> verifyLiveness({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
  }) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.verifyLiveness(
      challenges: challenges,
      timeout: timeout,
    );
  }

  /// Compares two still images directly through the recognition
  /// engine, bypassing camera/liveness entirely. Requires
  /// [FaceBiometricConfig.embeddingModelAssetPath] to be configured.
  static Future<FaceMatchResult> compare({
    required Uint8List firstImage,
    required Uint8List secondImage,
  }) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.compare(
      firstImage: firstImage,
      secondImage: secondImage,
    );
  }

  static Future<bool> isEnrolled({required String userId}) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.isEnrolled(userId: userId);
  }

  static Future<void> deleteEnrollment({required String userId}) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.deleteEnrollment(userId: userId);
  }

  static Future<List<String>> getEnrolledUsers() {
    _checkInitialized();
    return FaceBiometricPlatform.instance.getEnrolledUsers();
  }

  static Future<void> clearAllEnrollments() {
    _checkInitialized();
    return FaceBiometricPlatform.instance.clearAllEnrollments();
  }

  /// Authenticates using the OS biometric subsystem (Android
  /// `BiometricPrompt`, iOS `LocalAuthentication`) instead of this
  /// plugin's custom face recognition.
  ///
  /// Specify [authType] to explicitly control whether to request:
  /// - [DeviceAuthType.biometricOnly]: Any biometric (Fingerprint or Face)
  /// - [DeviceAuthType.strongBiometricOnly]: Class 3 biometrics only (Fingerprint on most Android devices)
  /// - [DeviceAuthType.deviceCredentialOnly]: Pattern, PIN, or Password ONLY (no biometrics)
  /// - [DeviceAuthType.biometricWithCredential]: Biometrics with Pattern/PIN fallback
  static Future<bool> authenticateWithDeviceBiometrics({
    String? reason,
    DeviceAuthType authType = DeviceAuthType.biometricOnly,
  }) {
    _checkInitialized();
    return FaceBiometricPlatform.instance.authenticateWithDeviceBiometrics(
      reason: reason,
      authType: authType,
    );
  }
}
