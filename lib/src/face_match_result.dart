/// Result of [FaceBiometric.compare]. Purely a recognition-engine
/// output — no liveness or anti-spoof involved, since it operates on
/// two static images. Useful for testing the recognition engine in
/// isolation from the camera/liveness pipeline (see README).
class FaceMatchResult {
  const FaceMatchResult({
    required this.isMatch,
    required this.similarity,
    required this.threshold,
  });

  factory FaceMatchResult.fromMap(Map<Object?, Object?> map) {
    return FaceMatchResult(
      isMatch: map['isMatch']! as bool,
      similarity: (map['similarity']! as num).toDouble(),
      threshold: (map['threshold']! as num).toDouble(),
    );
  }

  final bool isMatch;
  final double similarity;
  final double threshold;
}
