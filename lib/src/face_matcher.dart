import 'dart:math' as math;

import 'face_match_result.dart';

/// Pure-Dart reference implementation of the cosine-similarity formula
/// used for 1:1 face matching.
///
/// The authoritative comparison at runtime happens natively (Kotlin
/// `FaceMatcher` / Swift `FaceMatcher`) so it can run directly against
/// native embedding buffers without a platform-channel round trip.
/// This class exists so the formula itself — the actual security-
/// relevant math — has deterministic, fast Dart unit tests that don't
/// require a device/emulator, and native implementations are required
/// to match it exactly (see `test/face_match_test.dart`).
class FaceMatcher {
  const FaceMatcher();

  /// Cosine similarity of [a] and [b]: dot(a,b) / (||a|| * ||b||).
  ///
  /// Returns a value in [-1.0, 1.0] (typically [0.0, 1.0] for
  /// normalized face embeddings). Throws [ArgumentError] if the
  /// vectors have different lengths or either is empty.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.isEmpty || b.isEmpty) {
      throw ArgumentError('Embeddings must not be empty.');
    }
    if (a.length != b.length) {
      throw ArgumentError(
        'Embedding dimension mismatch: ${a.length} vs ${b.length}. '
        'This usually means the two embeddings came from different '
        'model versions; see FaceTemplate.isCompatibleWith.',
      );
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0.0 || normB == 0.0) {
      // A zero vector has no defined direction; treat as no similarity
      // rather than dividing by zero.
      return 0.0;
    }

    final double similarity = dot / (math.sqrt(normA) * math.sqrt(normB));
    // Guard against tiny floating point overshoot past +-1.0.
    return similarity.clamp(-1.0, 1.0);
  }

  /// Applies [threshold] to [cosineSimilarity] to produce a
  /// [FaceMatchResult]. The threshold decision is centralized here so
  /// it's exercised by the same tests as the similarity formula.
  FaceMatchResult match(
    List<double> a,
    List<double> b, {
    required double threshold,
  }) {
    final double similarity = cosineSimilarity(a, b);
    return FaceMatchResult(
      isMatch: similarity >= threshold,
      similarity: similarity,
      threshold: threshold,
    );
  }
}
