import '../face_match_result.dart';

/// Result of comparing two face images directly.
class FaceComparisonResult {
  const FaceComparisonResult({
    required this.isMatch,
    required this.similarity,
    required this.threshold,
    this.firstFaceDetected = true,
    this.secondFaceDetected = true,
  });

  /// True if cosine similarity >= threshold.
  final bool isMatch;

  /// Cosine similarity score in range (-1.0 to 1.0).
  final double similarity;

  /// The decision threshold applied.
  final double threshold;

  /// Whether a face was detected in the first image.
  final bool firstFaceDetected;

  /// Whether a face was detected in the second image.
  final bool secondFaceDetected;

  factory FaceComparisonResult.fromMatchResult(FaceMatchResult match) {
    return FaceComparisonResult(
      isMatch: match.isMatch,
      similarity: match.similarity,
      threshold: match.threshold,
    );
  }

  @override
  String toString() =>
      'FaceComparisonResult(isMatch: $isMatch, similarity: ${similarity.toStringAsFixed(3)}, threshold: $threshold)';
}
