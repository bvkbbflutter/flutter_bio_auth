import 'face_biometric_config.dart';

/// Configuration options for the unified [FaceAI] SDK.
class FaceAIConfig {
  const FaceAIConfig({
    this.enableFaceDetection = true,
    this.enableExpressionRecognition = true,
    this.enableFaceRecognition = true,
    this.enableLivenessDetection = true,
    this.enableLocalAuthentication = true,
    this.enableDeliveryCompliance = true,
    this.recognitionThreshold = 0.68,
    this.embeddingModelAssetPath = 'assets/models/mobilefacenet.tflite',
    this.antiSpoofModelAssetPath,
  });

  final bool enableFaceDetection;
  final bool enableExpressionRecognition;
  final bool enableFaceRecognition;
  final bool enableLivenessDetection;
  final bool enableLocalAuthentication;
  final bool enableDeliveryCompliance;

  final double recognitionThreshold;
  final String? embeddingModelAssetPath;
  final String? antiSpoofModelAssetPath;

  /// Converts this configuration to the underlying [FaceBiometricConfig].
  FaceBiometricConfig toBiometricConfig() {
    return FaceBiometricConfig(
      recognitionThreshold: recognitionThreshold,
      enableLiveness: enableLivenessDetection,
      enableAntiSpoofing: antiSpoofModelAssetPath != null,
      embeddingModelAssetPath: embeddingModelAssetPath,
      antiSpoofModelAssetPath: antiSpoofModelAssetPath,
    );
  }
}
