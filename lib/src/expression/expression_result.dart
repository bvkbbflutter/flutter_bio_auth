import 'facial_expression.dart';

/// Result of facial expression analysis.
class ExpressionResult {
  const ExpressionResult({
    required this.expression,
    required this.confidence,
    required this.expressions,
    this.smilingProbability,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
  });

  /// The dominant detected facial expression.
  final FacialExpression expression;

  /// Confidence of the dominant expression in range (0.0 to 1.0).
  final double confidence;

  /// Probability distribution across supported expressions.
  final Map<FacialExpression, double> expressions;

  /// Specific probability of smiling (0.0 to 1.0).
  final double? smilingProbability;

  /// Probability that left eye is open (0.0 to 1.0).
  final double? leftEyeOpenProbability;

  /// Probability that right eye is open (0.0 to 1.0).
  final double? rightEyeOpenProbability;

  /// Convenience helper: whether the user is smiling with >= 0.70 confidence.
  bool get isSmiling =>
      expression == FacialExpression.smile ||
      (smilingProbability ?? 0.0) >= 0.70;

  /// Convenience helper: whether user is blinking (both eyes closed).
  bool get isBlinking =>
      (leftEyeOpenProbability ?? 1.0) < 0.25 &&
      (rightEyeOpenProbability ?? 1.0) < 0.25;

  factory ExpressionResult.fromProbabilities({
    double? smilingProbability,
    double? leftEyeOpenProbability,
    double? rightEyeOpenProbability,
  }) {
    final double smile = smilingProbability ?? 0.0;
    final double leftOpen = leftEyeOpenProbability ?? 1.0;
    final double rightOpen = rightEyeOpenProbability ?? 1.0;

    FacialExpression dominant = FacialExpression.neutral;
    double maxConf = 0.5;

    if (smile >= 0.65) {
      dominant = FacialExpression.smile;
      maxConf = smile;
    } else if (leftOpen < 0.25 && rightOpen < 0.25) {
      dominant = FacialExpression.blink;
      maxConf = 0.90;
    } else if ((leftOpen < 0.25 && rightOpen > 0.6) ||
        (rightOpen < 0.25 && leftOpen > 0.6)) {
      dominant = FacialExpression.wink;
      maxConf = 0.85;
    } else {
      dominant = FacialExpression.neutral;
      maxConf = (1.0 - smile).clamp(0.0, 1.0);
    }

    final map = <FacialExpression, double>{
      FacialExpression.smile: smile,
      FacialExpression.neutral: (1.0 - smile).clamp(0.0, 1.0),
      FacialExpression.blink: ((1.0 - leftOpen) + (1.0 - rightOpen)) / 2.0,
    };

    return ExpressionResult(
      expression: dominant,
      confidence: maxConf,
      expressions: map,
      smilingProbability: smilingProbability,
      leftEyeOpenProbability: leftEyeOpenProbability,
      rightEyeOpenProbability: rightEyeOpenProbability,
    );
  }

  @override
  String toString() =>
      'ExpressionResult(expression: $expression, confidence: ${confidence.toStringAsFixed(2)})';
}
