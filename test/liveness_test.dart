import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LivenessChallengeSpec.defaults', () {
    test('every LivenessChallenge value has a default spec', () {
      for (final LivenessChallenge challenge in LivenessChallenge.values) {
        expect(
          LivenessChallengeSpec.defaults.containsKey(challenge),
          isTrue,
          reason: '$challenge is missing a default spec',
        );
      }
    });

    test('every default spec has a non-empty instruction', () {
      for (final LivenessChallengeSpec spec
          in LivenessChallengeSpec.defaults.values) {
        expect(spec.instruction, isNotEmpty);
      }
    });

    test('confidence thresholds are within [0, 1]', () {
      for (final LivenessChallengeSpec spec
          in LivenessChallengeSpec.defaults.values) {
        expect(spec.confidenceThreshold, inInclusiveRange(0.0, 1.0));
      }
    });

    test('discrete gestures require a return to neutral', () {
      expect(
        LivenessChallengeSpec
            .defaults[LivenessChallenge.blink]!.requiresReturnToNeutral,
        isTrue,
      );
      expect(
        LivenessChallengeSpec
            .defaults[LivenessChallenge.turnLeft]!.requiresReturnToNeutral,
        isTrue,
      );
    });

    test('continuous distance gestures do not require return to neutral', () {
      expect(
        LivenessChallengeSpec
            .defaults[LivenessChallenge.moveCloser]!.requiresReturnToNeutral,
        isFalse,
      );
    });
  });

  group('LivenessChallengeProgress.fromMap', () {
    test('parses an in-progress challenge', () {
      final LivenessChallengeProgress progress =
          LivenessChallengeProgress.fromMap(<Object?, Object?>{
        'challenge': 'blink',
        'instruction': 'Blink both eyes',
        'progress': 0.5,
        'confidence': 0.6,
        'completed': false,
        'timedOut': false,
      });
      expect(progress.challenge, LivenessChallenge.blink);
      expect(progress.completed, isFalse);
    });

    test('defaults timedOut to false when omitted', () {
      final LivenessChallengeProgress progress =
          LivenessChallengeProgress.fromMap(<Object?, Object?>{
        'challenge': 'smile',
        'instruction': 'Smile',
        'progress': 1.0,
        'confidence': 0.9,
        'completed': true,
      });
      expect(progress.timedOut, isFalse);
    });
  });

  group('LivenessResult.fromMap', () {
    test('parses a passing sequence', () {
      final LivenessResult result = LivenessResult.fromMap(<Object?, Object?>{
        'passed': true,
        'overallScore': 0.93,
        'completedChallenges': <String>['blink', 'turnLeft'],
        'failedChallenge': null,
      });
      expect(result.passed, isTrue);
      expect(result.completedChallenges, <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.turnLeft,
      ]);
      expect(result.failedChallenge, isNull);
    });

    test('parses a failure with the failed challenge identified', () {
      final LivenessResult result = LivenessResult.fromMap(<Object?, Object?>{
        'passed': false,
        'overallScore': 0.40,
        'completedChallenges': <String>['blink'],
        'failedChallenge': 'turnRight',
      });
      expect(result.passed, isFalse);
      expect(result.failedChallenge, LivenessChallenge.turnRight);
    });
  });
}
