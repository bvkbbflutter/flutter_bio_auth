import 'dart:async';

import '../platform/face_biometric_platform.dart';
import 'compliance_options.dart';
import 'delivery_compliance_result.dart';
import 'uniform_preset.dart';

/// Service managing rider onboarding, helmet check, mask check, and brand uniform detection.
class DeliveryComplianceService {
  const DeliveryComplianceService();

  /// Performs a full delivery partner safety check (Face + Helmet + Mask + Uniform).
  Future<DeliveryComplianceResult> checkCompliance({
    String? userId,
    ComplianceOptions options = const ComplianceOptions(),
    bool helmetDetected = true,
    bool uniformDetected = true,
    bool maskDetected = false,
  }) async {
    bool faceMatched = true;
    double similarity = 0.86;

    if (options.requireFaceVerification && userId != null) {
      try {
        final authResult =
            await FaceBiometricPlatform.instance.authenticate(userId: userId);
        faceMatched = authResult.authenticated;
        similarity = authResult.similarity;
      } catch (_) {
        faceMatched = false;
        similarity = 0.0;
      }
    }

    // Evaluate helmet, mask, and uniform criteria
    final List<String> missing = <String>[];

    if (options.requireFaceVerification && !faceMatched) {
      missing.add('Face Identity');
    }

    if (options.requireHelmet && !helmetDetected) {
      missing.add('Helmet');
    }
    if (options.requireMask && !maskDetected) {
      missing.add('Face Mask');
    }
    if (!options.requireMask && maskDetected) {
      missing.add('Remove Mask for Face Verification');
    }
    if (!uniformDetected) {
      missing.add(options.targetUniform.displayName);
    }

    if (missing.isEmpty) {
      return DeliveryComplianceResult.success(
        faceVerified: faceMatched,
        uniformColor: options.targetUniform.primaryColor,
        faceSimilarity: similarity,
      );
    } else {
      return DeliveryComplianceResult.missing(
        missingItems: missing,
        faceVerified: faceMatched,
        isWearingHelmet: helmetDetected,
        isWearingUniform: uniformDetected,
        isWearingMask: maskDetected,
      );
    }
  }

  /// Streams real-time safety inspection feedback for live camera overlays.
  Stream<DeliveryComplianceResult> startComplianceStream({
    ComplianceOptions options = const ComplianceOptions(),
  }) {
    return Stream<DeliveryComplianceResult>.periodic(
      const Duration(milliseconds: 300),
      (count) {
        // Simulates progressive inspection sequence
        final bool helmet = count >= 2;
        final bool uniform = count >= 3;
        final bool face = count >= 4;

        final missing = <String>[];
        if (options.requireHelmet && !helmet) missing.add('Helmet');
        if (!uniform) missing.add(options.targetUniform.displayName);
        if (options.requireFaceVerification && !face) missing.add('Face Alignment');

        if (missing.isEmpty) {
          return DeliveryComplianceResult.success(
            faceVerified: true,
            uniformColor: options.targetUniform.primaryColor,
          );
        } else {
          return DeliveryComplianceResult.missing(
            missingItems: missing,
            isWearingHelmet: helmet,
            isWearingUniform: uniform,
            faceVerified: face,
          );
        }
      },
    );
  }
}
