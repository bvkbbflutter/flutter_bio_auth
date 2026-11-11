/// A single active-liveness action the user is asked to perform.
///
/// Detection of every challenge here is backed by native, model-free
/// platform face APIs (ML Kit face classification/Euler angles on
/// Android, `VNFaceObservation` landmarks/roll-yaw on iOS) plus
/// temporal smoothing — none of these require a
/// bundled AI model.
enum LivenessChallenge {
  blink,
  smile,
  turnLeft,
  turnRight,
  lookUp,
  lookDown,
  moveCloser,
  moveAway,
}

/// Human-readable instruction and default tuning for a challenge.
/// Centralizes the "magic numbers" the challenge state machine uses so
/// they aren't scattered through native code.
class LivenessChallengeSpec {
  const LivenessChallengeSpec({
    required this.challenge,
    required this.instruction,
    required this.confidenceThreshold,
    required this.requiresReturnToNeutral,
  });

  final LivenessChallenge challenge;
  final String instruction;

  /// Minimum per-challenge confidence in (0 to 1) for completion.
  final double confidenceThreshold;

  /// Whether the state machine must observe a neutral state both
  /// before and after the action (e.g. blink: open -> closed -> open)
  /// to prevent a single static extreme frame from passing.
  final bool requiresReturnToNeutral;

  static const Map<LivenessChallenge, LivenessChallengeSpec> defaults =
      <LivenessChallenge, LivenessChallengeSpec>{
    LivenessChallenge.blink: LivenessChallengeSpec(
      challenge: LivenessChallenge.blink,
      instruction: 'Blink both eyes',
      confidenceThreshold: 0.75,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.smile: LivenessChallengeSpec(
      challenge: LivenessChallenge.smile,
      instruction: 'Smile',
      confidenceThreshold: 0.70,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.turnLeft: LivenessChallengeSpec(
      challenge: LivenessChallenge.turnLeft,
      instruction: 'Turn your head to the left',
      confidenceThreshold: 0.70,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.turnRight: LivenessChallengeSpec(
      challenge: LivenessChallenge.turnRight,
      instruction: 'Turn your head to the right',
      confidenceThreshold: 0.70,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.lookUp: LivenessChallengeSpec(
      challenge: LivenessChallenge.lookUp,
      instruction: 'Tilt your head up',
      confidenceThreshold: 0.70,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.lookDown: LivenessChallengeSpec(
      challenge: LivenessChallenge.lookDown,
      instruction: 'Tilt your head down',
      confidenceThreshold: 0.70,
      requiresReturnToNeutral: true,
    ),
    LivenessChallenge.moveCloser: LivenessChallengeSpec(
      challenge: LivenessChallenge.moveCloser,
      instruction: 'Move closer to the camera',
      confidenceThreshold: 0.65,
      requiresReturnToNeutral: false,
    ),
    LivenessChallenge.moveAway: LivenessChallengeSpec(
      challenge: LivenessChallenge.moveAway,
      instruction: 'Move away from the camera',
      confidenceThreshold: 0.65,
      requiresReturnToNeutral: false,
    ),
  };
}
