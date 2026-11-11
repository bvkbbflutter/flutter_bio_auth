/// Options for expression recognition.
class ExpressionOptions {
  const ExpressionOptions({
    this.confidenceThreshold = 0.65,
    this.maxFaces = 1,
    this.throttleInterval = const Duration(milliseconds: 100),
  });

  /// Minimum confidence required to accept a detected expression.
  final double confidenceThreshold;

  /// Maximum faces to analyze in frame.
  final int maxFaces;

  /// Interval between consecutive stream emissions.
  final Duration throttleInterval;
}
