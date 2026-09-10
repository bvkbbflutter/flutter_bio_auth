import 'liveness_challenge.dart';

/// Live progress of a single challenge, streamed from native to Dart
/// while a challenge is in progress (never raw frames).
class LivenessChallengeProgress {
  const LivenessChallengeProgress({
    required this.challenge,
    required this.instruction,
    required this.progress,
    required this.confidence,
    required this.completed,
    required this.timedOut,
  });

  factory LivenessChallengeProgress.fromMap(Map<Object?, Object?> map) {
    return LivenessChallengeProgress(
      challenge: LivenessChallenge.values.byName(map['challenge']! as String),
      instruction: map['instruction']! as String,
      progress: (map['progress']! as num).toDouble(),
      confidence: (map['confidence']! as num).toDouble(),
      completed: map['completed']! as bool,
      timedOut: map['timedOut'] as bool? ?? false,
    );
  }

  final LivenessChallenge challenge;
  final String instruction;

  /// 0.0-1.0 progress toward completion (e.g. how far into the blink
  /// or turn the temporal state machine has observed).
  final double progress;

  /// 0.0-1.0 confidence the action genuinely occurred.
  final double confidence;
  final bool completed;
  final bool timedOut;
}

/// Aggregate result of an entire liveness challenge sequence.
class LivenessResult {
  const LivenessResult({
    required this.passed,
    required this.overallScore,
    required this.completedChallenges,
    required this.failedChallenge,
  });

  factory LivenessResult.fromMap(Map<Object?, Object?> map) {
    return LivenessResult(
      passed: map['passed']! as bool,
      overallScore: (map['overallScore']! as num).toDouble(),
      completedChallenges: (map['completedChallenges']! as List<Object?>)
          .map((Object? e) => LivenessChallenge.values.byName(e! as String))
          .toList(),
      failedChallenge: map['failedChallenge'] != null
          ? LivenessChallenge.values.byName(map['failedChallenge']! as String)
          : null,
    );
  }

  final bool passed;
  final double overallScore;
  final List<LivenessChallenge> completedChallenges;
  final LivenessChallenge? failedChallenge;
}
