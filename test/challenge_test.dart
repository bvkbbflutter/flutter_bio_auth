import 'dart:math';

import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ChallengeSequencer sequencer = ChallengeSequencer();

  group('ChallengeSequencer.buildSequence', () {
    test('returns an empty sequence for an empty pool', () {
      expect(
        sequencer
            .buildSequence(pool: const <LivenessChallenge>[], randomize: false),
        isEmpty,
      );
    });

    test('preserves order when randomize is false', () {
      const List<LivenessChallenge> pool = <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.turnLeft,
        LivenessChallenge.turnRight,
      ];
      final List<LivenessChallenge> sequence = sequencer.buildSequence(
        pool: pool,
        randomize: false,
      );
      expect(sequence, pool);
    });

    test('de-duplicates while preserving first-seen order', () {
      const List<LivenessChallenge> pool = <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.turnLeft,
        LivenessChallenge.blink,
      ];
      final List<LivenessChallenge> sequence = sequencer.buildSequence(
        pool: pool,
        randomize: false,
      );
      expect(sequence, <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.turnLeft,
      ]);
    });

    test('randomized sequence contains exactly the same unique elements', () {
      const List<LivenessChallenge> pool = <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.smile,
        LivenessChallenge.turnLeft,
        LivenessChallenge.turnRight,
        LivenessChallenge.lookUp,
      ];
      final List<LivenessChallenge> sequence = sequencer.buildSequence(
        pool: pool,
        randomize: true,
        random: Random(42),
      );
      expect(sequence.toSet(), pool.toSet());
      expect(sequence.length, pool.length);
    });

    test('is deterministic given the same seeded Random', () {
      const List<LivenessChallenge> pool = <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.smile,
        LivenessChallenge.turnLeft,
        LivenessChallenge.turnRight,
      ];
      final List<LivenessChallenge> first = sequencer.buildSequence(
        pool: pool,
        randomize: true,
        random: Random(7),
      );
      final List<LivenessChallenge> second = sequencer.buildSequence(
        pool: pool,
        randomize: true,
        random: Random(7),
      );
      expect(first, second);
    });

    test('single-challenge pool is unaffected by randomize', () {
      const List<LivenessChallenge> pool = <LivenessChallenge>[
        LivenessChallenge.blink,
      ];
      expect(
        sequencer.buildSequence(pool: pool, randomize: true),
        <LivenessChallenge>[LivenessChallenge.blink],
      );
    });
  });
}
