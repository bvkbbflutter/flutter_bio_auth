import 'package:flutter/material.dart';
import 'uniform_preset.dart';

/// Configuration options for delivery partner safety & uniform compliance.
class ComplianceOptions {
  const ComplianceOptions({
    this.requireFaceVerification = true,
    this.requireHelmet = true,
    this.requireMask = false,
    this.targetUniform = UniformPreset.zeptoPurple,
    this.customUniformColor,
    this.minUniformConfidence = 0.60,
    this.minHelmetConfidence = 0.65,
    this.minMaskConfidence = 0.65,
  });

  /// Whether to verify the rider's face identity against enrolled profile.
  final bool requireFaceVerification;

  /// Whether wearing a motorcycle helmet is mandatory.
  final bool requireHelmet;

  /// Whether wearing a mask is mandatory (true for pandemic rules, false if face must be exposed).
  final bool requireMask;

  /// Target delivery brand uniform.
  final UniformPreset targetUniform;

  /// Optional custom color when [targetUniform] is [UniformPreset.custom].
  final Color? customUniformColor;

  /// Minimum confidence [0.0, 1.0] to accept uniform match.
  final double minUniformConfidence;

  /// Minimum confidence [0.0, 1.0] to confirm helmet presence.
  final double minHelmetConfidence;

  /// Minimum confidence [0.0, 1.0] for mask detection.
  final double minMaskConfidence;
}
