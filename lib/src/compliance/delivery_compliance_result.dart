import 'package:flutter/material.dart';

/// Individual compliance check item result with status, confidence, and explanation.
class ComplianceCheckItem {
  const ComplianceCheckItem({
    required this.name,
    required this.passed,
    required this.confidence,
    required this.reason,
    this.required = true,
  });

  final String name;
  final bool passed;
  final double confidence;
  final String reason;
  final bool required;

  @override
  String toString() => '$name: ${passed ? "PASS" : "FAIL"} ($reason)';
}

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
    required this.isMotorcycleVerified,
    required this.motorcycleConfidence,
    required this.missingItems,
    this.checks = const <ComplianceCheckItem>[],
    this.statusMessage = 'Inspection Complete',
    this.detectedUniformColor,
    this.faceSimilarity,
    this.uniformReason,
    this.helmetReason,
    this.motorcycleReason,
    this.faceReason,
    this.maskReason,
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

  /// Motorcycle / two-wheeler context verification status.
  final bool isMotorcycleVerified;
  final double motorcycleConfidence;

  /// List of safety items that failed compliance (e.g. 'Helmet', 'Uniform').
  final List<String> missingItems;

  /// Detailed per-gate compliance breakdown.
  final List<ComplianceCheckItem> checks;

  /// User-friendly summary message.
  final String statusMessage;

  /// Approximate dominant torso color detected.
  final Color? detectedUniformColor;

  /// Face matching cosine similarity.
  final double? faceSimilarity;

  /// Individual explanations.
  final String? uniformReason;
  final String? helmetReason;
  final String? motorcycleReason;
  final String? faceReason;
  final String? maskReason;

  factory DeliveryComplianceResult.evaluated({
    required bool faceVerified,
    required double faceConfidence,
    required String faceReason,
    required bool isWearingHelmet,
    required double helmetConfidence,
    required String helmetReason,
    required bool isWearingUniform,
    required double uniformConfidence,
    required String uniformReason,
    required bool isMotorcycleVerified,
    required double motorcycleConfidence,
    required String motorcycleReason,
    required bool isWearingMask,
    required double maskConfidence,
    required String maskReason,
    required bool requireFace,
    required bool requireHelmet,
    required bool requireUniform,
    required bool requireMotorcycle,
    required bool requireMask,
    List<String>? explicitMissingItems,
    Color? detectedColor,
    double? faceSimilarity,
  }) {
    final List<String> missing = explicitMissingItems != null
        ? List<String>.from(explicitMissingItems)
        : <String>[];
    final List<ComplianceCheckItem> allChecks = <ComplianceCheckItem>[
      ComplianceCheckItem(
        name: 'Face Identity',
        passed: faceVerified,
        confidence: faceConfidence,
        reason: faceReason,
        required: requireFace,
      ),
      ComplianceCheckItem(
        name: 'Motorcycle / Stance',
        passed: isMotorcycleVerified,
        confidence: motorcycleConfidence,
        reason: motorcycleReason,
        required: requireMotorcycle,
      ),
      ComplianceCheckItem(
        name: 'Safety Helmet',
        passed: isWearingHelmet,
        confidence: helmetConfidence,
        reason: helmetReason,
        required: requireHelmet,
      ),
      ComplianceCheckItem(
        name: 'Brand Uniform',
        passed: isWearingUniform,
        confidence: uniformConfidence,
        reason: uniformReason,
        required: requireUniform,
      ),
      ComplianceCheckItem(
        name: 'Face Mask',
        passed: isWearingMask,
        confidence: maskConfidence,
        reason: maskReason,
        required: requireMask,
      ),
    ];

    if (explicitMissingItems == null) {
      if (requireFace && !faceVerified) {
        missing.add('Face Identity');
      }
      if (requireMotorcycle && !isMotorcycleVerified) {
        missing.add('Motorcycle Check');
      }
      if (requireHelmet && !isWearingHelmet) {
        missing.add('Helmet');
      }
      if (requireUniform && !isWearingUniform) {
        missing.add('Uniform');
      }
      if (requireMask && !isWearingMask) {
        missing.add('Face Mask');
      }
    }

    final bool ready = missing.isEmpty;
    final String summary = ready
        ? 'All compliance gates passed! Ready for delivery duty.'
        : 'Shift Check-In Failed: ${missing.join(", ")} missing or non-compliant.';

    return DeliveryComplianceResult(
      isReady: ready,
      faceVerified: faceVerified,
      isWearingHelmet: isWearingHelmet,
      helmetConfidence: helmetConfidence,
      isWearingMask: isWearingMask,
      maskConfidence: maskConfidence,
      isWearingUniform: isWearingUniform,
      uniformConfidence: uniformConfidence,
      isMotorcycleVerified: isMotorcycleVerified,
      motorcycleConfidence: motorcycleConfidence,
      missingItems: missing,
      checks: allChecks,
      statusMessage: summary,
      detectedUniformColor: detectedColor,
      faceSimilarity: faceSimilarity,
      uniformReason: uniformReason,
      helmetReason: helmetReason,
      motorcycleReason: motorcycleReason,
      faceReason: faceReason,
      maskReason: maskReason,
    );
  }

  factory DeliveryComplianceResult.success({
    bool faceVerified = true,
    double helmetConfidence = 0.92,
    bool isWearingMask = false,
    double uniformConfidence = 0.88,
    Color? uniformColor,
    double faceSimilarity = 0.85,
  }) {
    return DeliveryComplianceResult.evaluated(
      faceVerified: faceVerified,
      faceConfidence: faceSimilarity,
      faceReason: 'Rider identity verified and matched with account profile',
      isWearingHelmet: true,
      helmetConfidence: helmetConfidence,
      helmetReason: 'Full-coverage safety helmet verified with chin-strap',
      isWearingUniform: true,
      uniformConfidence: uniformConfidence,
      uniformReason: 'Compliant brand uniform detected within color spectrum',
      isMotorcycleVerified: true,
      motorcycleConfidence: 0.90,
      motorcycleReason:
          'Rider two-wheeler context and upright posture confirmed',
      isWearingMask: isWearingMask,
      maskConfidence: 0.15,
      maskReason:
          isWearingMask ? 'Mask compliant' : 'Face unmasked for identification',
      requireFace: true,
      requireHelmet: true,
      requireUniform: true,
      requireMotorcycle: true,
      requireMask: false,
      detectedColor: uniformColor,
      faceSimilarity: faceSimilarity,
    );
  }

  factory DeliveryComplianceResult.missing({
    required List<String> missingItems,
    bool faceVerified = false,
    bool isWearingHelmet = false,
    bool isWearingUniform = false,
    bool isWearingMask = false,
    bool isMotorcycleVerified = false,
  }) {
    return DeliveryComplianceResult.evaluated(
      faceVerified: faceVerified,
      faceConfidence: faceVerified ? 0.85 : 0.20,
      faceReason:
          faceVerified ? 'Face verified' : 'Face not recognized or aligned',
      isWearingHelmet: isWearingHelmet,
      helmetConfidence: isWearingHelmet ? 0.88 : 0.25,
      helmetReason:
          isWearingHelmet ? 'Helmet verified' : 'Helmet missing or not worn',
      isWearingUniform: isWearingUniform,
      uniformConfidence: isWearingUniform ? 0.88 : 0.25,
      uniformReason: isWearingUniform
          ? 'Uniform compliant'
          : 'Uniform color mismatch or missing',
      isMotorcycleVerified: isMotorcycleVerified,
      motorcycleConfidence: isMotorcycleVerified ? 0.88 : 0.25,
      motorcycleReason: isMotorcycleVerified
          ? 'Vehicle verified'
          : 'Motorcycle not detected in frame',
      isWearingMask: isWearingMask,
      maskConfidence: isWearingMask ? 0.85 : 0.15,
      maskReason: 'Mask status evaluated',
      requireFace: true,
      requireHelmet: true,
      requireUniform: true,
      requireMotorcycle: true,
      requireMask: false,
      explicitMissingItems: missingItems,
    );
  }

  @override
  String toString() =>
      'DeliveryComplianceResult(isReady: $isReady, helmet: $isWearingHelmet, uniform: $isWearingUniform, motorcycle: $isMotorcycleVerified, face: $faceVerified)';
}
