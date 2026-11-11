import 'dart:io';
import 'dart:typed_data';

import 'authentication/authentication_service.dart';
import 'authentication/local_auth_result.dart';
import 'compliance/compliance_options.dart';
import 'compliance/delivery_compliance_result.dart';
import 'compliance/delivery_compliance_service.dart';
import 'diagnostics/device_capabilities.dart';
import 'expression/expression_options.dart';
import 'expression/expression_result.dart';
import 'expression/expression_service.dart';
import 'face_authentication_result.dart';
import 'face_biometric.dart';
import 'face_biometric_state.dart';
import 'face_enrollment_result.dart';
import 'face_ai_config.dart';
import 'liveness/liveness_options.dart';
import 'liveness/liveness_service.dart';
import 'liveness_challenge.dart';
import 'liveness_state.dart';
import 'models/model_manager.dart';
import 'platform/face_biometric_platform.dart';
import 'recognition/face_comparison_result.dart';
import 'recognition/face_recognition_service.dart';
import 'recognition/recognition_options.dart';

/// **Flutter Face Intelligence SDK (`FaceAI`)**
///
/// Unified, modular, AI-powered on-device face intelligence, recognition,
/// local device biometrics, active liveness, and delivery partner compliance.
class FaceAI {
  FaceAI._();

  static bool _initialized = false;
  static FaceAIConfig _config = const FaceAIConfig();

  /// Whether [initialize] has been called.
  static bool get isInitialized => _initialized;

  /// Current active configuration.
  static FaceAIConfig get config => _config;

  /// Subsystem for local device biometric authentication
  /// (Android BiometricPrompt & Apple LocalAuthentication).
  static const AuthenticationService auth = AuthenticationService();

  /// Subsystem for 1:1 face verification, template enrollment, and comparison.
  static const FaceRecognitionService recognition = FaceRecognitionService();

  /// Subsystem for facial expression classification and real-time sentiment streams.
  static const ExpressionService expression = ExpressionService();

  /// Subsystem for active challenge-response and passive anti-spoof liveness.
  static const LivenessService liveness = LivenessService();

  /// Subsystem for Zepto / Rider safety gear & uniform compliance.
  static const DeliveryComplianceService compliance =
      DeliveryComplianceService();

  /// Pluggable TFLite AI model registry and manager.
  static final FaceModelManager models = FaceModelManager();

  /// Initializes the Face Intelligence SDK with optional configuration.
  static Future<void> initialize({
    FaceAIConfig config = const FaceAIConfig(),
  }) async {
    _config = config;
    await models.initPersistence();
    await FaceBiometric.initialize(config: config.toBiometricConfig());
    _initialized = true;
  }

  /// Global session state stream.
  static Stream<FaceBiometricState> get stateStream =>
      FaceBiometricPlatform.instance.stateStream;

  // ---------------------------------------------------------------------------
  // Top-Level Convenience Methods
  // ---------------------------------------------------------------------------

  /// Performs device-level local biometric authentication.
  static Future<LocalAuthResult> authenticate({
    String reason = 'Authenticate to access application',
    bool biometricOnly = true,
  }) {
    return auth.authenticate(reason: reason, biometricOnly: biometricOnly);
  }

  /// Enrolls a face identity into secure on-device storage.
  static Future<FaceEnrollmentResult> enrollFace({
    required String userId,
    RecognitionOptions? options,
  }) {
    return recognition.enrollFace(userId: userId, options: options);
  }

  /// Verifies a captured face against the enrolled template of [userId].
  static Future<FaceAuthenticationResult> verifyFace({
    required String userId,
    RecognitionOptions? options,
  }) {
    return recognition.verifyFace(userId: userId, options: options);
  }

  /// Compares two still face images directly (JPEG/PNG bytes).
  static Future<FaceComparisonResult> compareFaces({
    required Uint8List firstImage,
    required Uint8List secondImage,
    double threshold = 0.68,
  }) {
    return recognition.compareFaces(
      firstImage: firstImage,
      secondImage: secondImage,
      threshold: threshold,
    );
  }

  /// Detects expression from the active camera view.
  static Future<ExpressionResult> detectExpression({
    ExpressionOptions? options,
  }) {
    return expression.detectExpression(options: options);
  }

  /// Real-time expression update stream.
  static Stream<ExpressionResult> startExpressionStream({
    ExpressionOptions? options,
  }) {
    return expression.startExpressionStream(options: options);
  }

  /// Runs active challenge-response liveness testing (blink, head turn, smile).
  static Future<LivenessResult> performLivenessCheck({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
    LivenessOptions? options,
  }) {
    return liveness.performLivenessCheck(
      challenges: challenges,
      timeout: timeout,
      options: options,
    );
  }

  /// Performs delivery partner compliance check (Face + Helmet + Mask + Uniform).
  static Future<DeliveryComplianceResult> checkDeliveryCompliance({
    String? userId,
    ComplianceOptions options = const ComplianceOptions(),
  }) {
    return compliance.checkCompliance(userId: userId, options: options);
  }

  /// Returns hardware and platform capabilities.
  static Future<DeviceCapabilities> getDeviceCapabilities() async {
    return DeviceCapabilities(
      supportsBiometrics: true,
      supportedDelegates: Platform.isAndroid
          ? const <String>['CPU (4 Threads)', 'NNAPI (Android)', 'GPU (OpenCL)']
          : const <String>['CPU', 'Metal / CoreML (Apple Silicon)'],
      availableCameras: const <String>['Front Camera', 'Back Camera'],
      runtimeVersion: 'TFLite 2.16.1 (On-Device)',
      platformName: Platform.operatingSystem,
    );
  }

  /// Cleanly releases camera, ML interpreters, and active sessions.
  static Future<void> dispose() {
    return FaceBiometricPlatform.instance.dispose();
  }
}
