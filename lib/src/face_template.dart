/// A versioned, model-tagged biometric template.
///
/// Instances in application memory hold a plaintext [embedding]
/// briefly (e.g. right after decryption, for comparison); the
/// persisted form on disk is always encrypted — see
/// `BiometricTemplateStorage` and the README "Security" section.
class FaceTemplate {
  const FaceTemplate({
    required this.version,
    required this.modelVersion,
    required this.embeddingDimension,
    required this.embedding,
    required this.createdAt,
  });

  factory FaceTemplate.fromMap(Map<String, Object?> map) {
    final List<Object?> raw = map['embedding']! as List<Object?>;
    return FaceTemplate(
      version: map['version']! as int,
      modelVersion: map['modelVersion']! as String,
      embeddingDimension: map['embeddingDimension']! as int,
      embedding: List<double>.unmodifiable(
        raw.map((Object? e) => (e! as num).toDouble()),
      ),
      createdAt: DateTime.parse(map['createdAt']! as String),
    );
  }

  static const int currentTemplateVersion = 1;

  final int version;
  final String modelVersion;
  final int embeddingDimension;
  final List<double> embedding;
  final DateTime createdAt;

  /// Whether this template was produced by a model compatible with
  /// [expectedModelVersion]/[expectedDimension]. Comparing embeddings
  /// across incompatible model versions produces meaningless
  /// similarity scores, so callers must check this before matching
  /// and request re-enrollment on mismatch (see README "Model
  /// versioning").
  bool isCompatibleWith({
    required String expectedModelVersion,
    required int expectedDimension,
  }) {
    return modelVersion == expectedModelVersion &&
        embeddingDimension == expectedDimension &&
        embedding.length == expectedDimension;
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'version': version,
        'modelVersion': modelVersion,
        'embeddingDimension': embeddingDimension,
        'embedding': embedding,
        'createdAt': createdAt.toIso8601String(),
      };
}
