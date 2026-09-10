import 'dart:math';

import 'liveness_challenge.dart';

/// Builds the ordered list of challenges for one session from
/// [FaceBiometricConfig.challenges] and
/// [FaceBiometricConfig.randomizeChallenges].
///
/// Mirrored by native `ChallengeEngine` implementations for the actual
/// live session; kept here as a pure function so the sequencing rules
/// have fast, deterministic Dart tests independent of the platform
/// channel.
class ChallengeSequencer {
  const ChallengeSequencer();

  /// Returns the challenges to run, in order.
  ///
  /// If [randomize] is false, returns [pool] unchanged. If [randomize]
  /// is true, returns a shuffled copy of [pool] with no duplicate
  /// challenge appearing twice, using [random] (injectable for
  /// deterministic tests).
  List<LivenessChallenge> buildSequence({
    required List<LivenessChallenge> pool,
    required bool randomize,
    Random? random,
  }) {
    if (pool.isEmpty) return const <LivenessChallenge>[];

    final List<LivenessChallenge> deduped = <LivenessChallenge>[
      ..._dedupePreservingOrder(pool),
    ];

    if (!randomize) return deduped;

    final List<LivenessChallenge> shuffled = List<LivenessChallenge>.from(
      deduped,
    )..shuffle(random ?? Random());
    return shuffled;
  }
}

/// Preserves first-seen order while de-duplicating.
Iterable<LivenessChallenge> _dedupePreservingOrder(
  List<LivenessChallenge> input,
) sync* {
  final Set<LivenessChallenge> seen = <LivenessChallenge>{};
  for (final LivenessChallenge c in input) {
    if (seen.add(c)) yield c;
  }
}
