import '../liveness_challenge.dart';

/// Configuration options for liveness verification.
class LivenessOptions {
  const LivenessOptions({
    this.challenges = const <LivenessChallenge>[
      LivenessChallenge.blink,
      LivenessChallenge.turnLeft,
      LivenessChallenge.turnRight,
    ],
    this.timeout = const Duration(seconds: 25),
    this.randomize = true,
    this.requireAntiSpoof = false,
  });

  /// The active challenge gestures to present.
  final List<LivenessChallenge> challenges;

  /// Overall timeout ceiling for completing the challenges.
  final Duration timeout;

  /// Whether challenge order should be randomized.
  final bool randomize;

  /// Whether passive anti-spoof model check is required.
  final bool requireAntiSpoof;
}
