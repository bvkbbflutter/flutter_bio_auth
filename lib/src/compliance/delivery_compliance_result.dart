import 'package:flutter/material.dart';

/// Detailed result of delivery partner safety gear & uniform compliance inspection.
class DeliveryComplianceResult {
  const DeliveryComplianceResult({
    required this.isReady,
    required this.faceVerified,
    required this.isWearingHelmet,
    required this.helmetConfidence,
    required this.isWearingMask,
    required this.maskConfidence,
    required this.isWearingUniform,
    required this.uniformConfidence,
    required this.missingItems,
    this.statusMessage = 'Inspection Complete',
    this.detectedUniformColor,
    this.faceSimilarity,
  });

  /// True when all required safety & gear conditions are satisfied.
  final bool isReady;

  /// Whether rider identity matched the enrolled account.
  final bool faceVerified;

  /// Helmet detection status.
  final bool isWearingHelmet;
  final double helmetConfidence;

  /// Mask detection status.
  final bool isWearingMask;
  final double maskConfidence;

  /// Company uniform match status.
  final bool isWearingUniform;
  final double uniformConfidence;

  /// List of safety items that failed compliance (e.g. ['Helmet', 'Uniform']).
  final List<String> missingItems;

  /// User-friendly summary message.
  final String statusMessage;

  /// Approximate dominant torso color detected.
  final Color? detectedUniformColor;

  /// Face matching cosine similarity.
  final double? faceSimilarity;

  factory DeliveryComplianceResult.success({
    bool faceVerified = true,
    double helmetConfidence = 0.92,
    bool isWearingMask = false,
    double uniformConfidence = 0.88,
    Color? uniformColor,
    double faceSimilarity = 0.85,
  }) {
    return DeliveryComplianceResult(
      isReady: true,
      faceVerified: faceVerified,
      isWearingHelmet: true,
      helmetConfidence: helmetConfidence,
      isWearingMask: isWearingMask,
      maskConfidence: 0.15,
      isWearingUniform: true,
      uniformConfidence: uniformConfidence,
      missingItems: const <String>[],
      statusMessage: 'All safety checks passed! Ready for delivery duty.',
      detectedUniformColor: uniformColor ?? const Color(0xFF5200FF),
      faceSimilarity: faceSimilarity,
    );
  }

  factory DeliveryComplianceResult.missing({
    required List<String> missingItems,
    bool faceVerified = false,
    bool isWearingHelmet = false,
    bool isWearingUniform = false,
    bool isWearingMask = false,
  }) {
    return DeliveryComplianceResult(
      isReady: false,
      faceVerified: faceVerified,
      isWearingHelmet: isWearingHelmet,
      helmetConfidence: isWearingHelmet ? 0.85 : 0.20,
      isWearingMask: isWearingMask,
      maskConfidence: isWearingMask ? 0.85 : 0.10,
      isWearingUniform: isWearingUniform,
      uniformConfidence: isWearingUniform ? 0.85 : 0.25,
      missingItems: missingItems,
      statusMessage: 'Compliance issue: Please check ${missingItems.join(", ")}.',
    );
  }

  @override
  String toString() =>
      'DeliveryComplianceResult(isReady: $isReady, helmet: $isWearingHelmet, uniform: $isWearingUniform, face: $faceVerified)';
}
