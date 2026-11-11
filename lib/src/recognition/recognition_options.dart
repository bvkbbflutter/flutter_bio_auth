/// Options for face recognition and verification.
class RecognitionOptions {
  const RecognitionOptions({
    this.threshold = 0.68,
    this.maxFaces = 1,
    this.extractLandmarks = true,
    this.enableQualityGate = true,
    this.enableLiveness,
  });

  /// Calibrated cosine similarity threshold (default ~0.68 for MobileFaceNet).
  final double threshold;

  /// Maximum number of faces allowed in frame (typically 1 for 1:1 auth).
  final int maxFaces;

  /// Whether to extract facial landmarks.
  final bool extractLandmarks;

  /// Whether to reject excessively blurry or off-screen faces.
  final bool enableQualityGate;

  /// Optional override for active liveness challenge during enrollment/authentication.
  final bool? enableLiveness;
}
