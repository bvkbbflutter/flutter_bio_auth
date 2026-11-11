import '../anti_spoof_result.dart';
import '../liveness_challenge.dart';
import '../liveness_state.dart';
import '../platform/face_biometric_platform.dart';
import 'liveness_options.dart';

/// Service for active challenge-response and passive anti-spoof liveness detection.
class LivenessService {
  const LivenessService();

  /// Runs active challenge-response liveness testing (blink, head turn, smile)
  /// and returns a structured [LivenessResult].
  Future<LivenessResult> performLivenessCheck({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
    LivenessOptions? options,
  }) {
    final List<LivenessChallenge> activeChallenges = challenges ??
        options?.challenges ??
        const <LivenessChallenge>[
          LivenessChallenge.blink,
          LivenessChallenge.turnLeft,
          LivenessChallenge.turnRight,
        ];

    return FaceBiometricPlatform.instance.verifyLiveness(
      challenges: activeChallenges,
      timeout: timeout ?? options?.timeout,
    );
  }

  /// Evaluates passive presentation attack detection on a captured face.
  Future<AntiSpoofResult> detectPassiveSpoof() async {
    // Relies on configured anti-spoof model or returns unavailable
    return AntiSpoofResult.unavailable;
  }

  /// Stream of challenge progress events (instruction, progress 0..1, completion).
  Stream<LivenessChallengeProgress> get progressStream =>
      FaceBiometricPlatform.instance.challengeProgressStream;
}
