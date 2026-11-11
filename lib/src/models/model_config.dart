import 'package:flutter/material.dart';

import 'model_source.dart';
import 'model_type.dart';

/// Specification and metadata describing a pluggable TFLite model.
class ModelConfig {
  const ModelConfig({
    required this.id,
    required this.type,
    required this.source,
    this.name,
    this.version = '1.0.0',
    this.inputSize = const Size(112, 112),
    this.embeddingDimensions = 192,
    this.calibratedThreshold = 0.68,
    this.sha256Checksum,
    this.labels = const <String>[],
  });

  /// Unique model identifier (e.g. 'mobilefacenet_v1').
  final String id;

  /// Model category / role.
  final ModelType type;

  /// File or asset location.
  final ModelSource source;

  /// Optional human-readable display name.
  final String? name;

  /// Semantic version of the model weights.
  final String version;

  /// Expected input tensor resolution.
  final Size inputSize;

  /// Output embedding dimension for recognition models.
  final int embeddingDimensions;

  /// Optimal calibrated threshold for cosine similarity.
  final double calibratedThreshold;

  /// Optional SHA-256 hash for integrity validation.
  final String? sha256Checksum;

  /// Classification labels if applicable.
  final List<String> labels;

  String get displayName => name ?? id;
}
