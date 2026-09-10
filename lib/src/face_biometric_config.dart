import 'face_authentication_mode.dart';
import 'liveness_challenge.dart';

/// Centralized, validated configuration for [FaceBiometric].
///
/// All thresholds are deliberately conservative defaults, not claims of
/// universal security. See the README "Threshold tuning" section: the
/// correct value depends on your recognition model, camera hardware,
/// and deployment risk tolerance.
class FaceBiometricConfig {
  const FaceBiometricConfig({
    this.recognitionThreshold = 0.65,
    this.livenessThreshold = 0.80,
    this.antiSpoofThreshold = 0.80,
    this.enableLiveness = true,
    this.enableAntiSpoofing = true,
    this.authenticationMode = FaceAuthenticationMode.faceWithLivenessAndAntiSpoof,
    this.captureFaceImage = false,
    this.sessionTimeout = const Duration(seconds: 90),
    this.challengeTimeout = const Duration(seconds: 25),
    this.randomizeChallenges = true,
    this.challenges = const <LivenessChallenge>[
      LivenessChallenge.blink,
      LivenessChallenge.turnLeft,
      LivenessChallenge.turnRight,
    ],
    this.requireSingleFace = true,
    this.requireCenteredFace = true,
    this.minimumFaceSize = 0.15,
    this.maximumFaceSize = 0.85,
    this.mirrorPreview = true,
    this.enableDebugLogs = false,
    this.embeddingModelAssetPath,
    this.antiSpoofModelAssetPath,
    this.embeddingDimension = 192,
  });

  /// Minimum cosine similarity in [0, 1] for two embeddings to be
  /// considered the same person. Tunable; see README.
  final double recognitionThreshold;

  /// Minimum aggregate liveness confidence in [0, 1] required to pass
  /// the active-liveness challenge sequence.
  final double livenessThreshold;

  /// Minimum "live" probability in [0, 1] from the passive anti-spoof
  /// model required to accept the frame as a real presentation.
  final double antiSpoofThreshold;

  /// Whether active liveness challenges run during enrollment/auth.
  final bool enableLiveness;

  /// Whether the passive anti-spoof model runs during authentication.
  /// If true but no model asset is configured, authentication fails
  /// closed (see [FaceAuthenticationMode]) rather than silently
  /// skipping the check.
  final bool enableAntiSpoofing;

  /// The combination of checks required for [FaceBiometric.authenticate]
  /// to succeed.
  final FaceAuthenticationMode authenticationMode;

  /// Whether to persist a JPEG of the enrolled face alongside the
  /// encrypted template. Off by default; see README "Privacy".
  final bool captureFaceImage;

  /// Hard ceiling on a single enroll/authenticate session.
  final Duration sessionTimeout;

  /// Hard ceiling on a single liveness challenge.
  final Duration challengeTimeout;

  /// Shuffle challenge order per session instead of using [challenges]
  /// verbatim.
  final bool randomizeChallenges;

  /// The pool of challenges a session may draw from.
  final List<LivenessChallenge> challenges;

  /// Reject frames containing more than one face.
  final bool requireSingleFace;

  /// Reject frames where the face is not roughly centered in frame.
  final bool requireCenteredFace;

  /// Minimum face bounding-box height as a fraction of frame height.
  final double minimumFaceSize;

  /// Maximum face bounding-box height as a fraction of frame height.
  final double maximumFaceSize;

  /// Mirror the front-camera preview horizontally (selfie convention).
  final bool mirrorPreview;

  /// Verbose native logging. Must default to false; never logs raw
  /// frames, face crops, embeddings, or key material regardless of
  /// this flag (see README "Security").
  final bool enableDebugLogs;

  /// Flutter asset path (e.g. `assets/models/face_embedding.tflite`) to
  /// a face-embedding model the *consuming app* bundles. Null/empty
  /// means recognition is unavailable and enroll/authenticate/compare
  /// will return [BiometricFailureReason.modelUnavailable] instead of a
  /// fabricated result. Detection, tracking, landmarks, quality, and
  /// active liveness all work without this being set.
  final String? embeddingModelAssetPath;

  /// Flutter asset path to a passive anti-spoof model, analogous to
  /// [embeddingModelAssetPath]. If [enableAntiSpoofing] is true and
  /// this is unset, authentication fails closed rather than silently
  /// downgrading security.
  final String? antiSpoofModelAssetPath;

  /// Expected output vector length of the configured embedding model.
  /// Used to validate model output and to detect stored-template /
  /// model-version mismatches.
  final int embeddingDimension;

  /// Throws [ArgumentError] describing the first invalid field found.
  /// Called by [FaceBiometric.initialize] before anything else runs.
  void validate() {
    _requireUnitRange(recognitionThreshold, 'recognitionThreshold');
    _requireUnitRange(livenessThreshold, 'livenessThreshold');
    _requireUnitRange(antiSpoofThreshold, 'antiSpoofThreshold');
    _requireUnitRange(minimumFaceSize, 'minimumFaceSize');
    _requireUnitRange(maximumFaceSize, 'maximumFaceSize');

    if (minimumFaceSize >= maximumFaceSize) {
      throw ArgumentError(
        'minimumFaceSize ($minimumFaceSize) must be less than '
        'maximumFaceSize ($maximumFaceSize).',
      );
    }
    if (sessionTimeout <= Duration.zero) {
      throw ArgumentError('sessionTimeout must be positive.');
    }
    if (challengeTimeout <= Duration.zero) {
      throw ArgumentError('challengeTimeout must be positive.');
    }
    if (challengeTimeout * challenges.length > sessionTimeout &&
        enableLiveness &&
        challenges.isNotEmpty) {
      throw ArgumentError(
        'sessionTimeout is too short to complete ${challenges.length} '
        'challenge(s) at challengeTimeout=$challengeTimeout each.',
      );
    }
    if (enableLiveness && challenges.isEmpty) {
      throw ArgumentError(
        'enableLiveness is true but challenges is empty.',
      );
    }
    if (embeddingDimension <= 0) {
      throw ArgumentError('embeddingDimension must be positive.');
    }
    if (authenticationMode ==
            FaceAuthenticationMode.faceWithLivenessAndAntiSpoof &&
        !enableAntiSpoofing) {
      throw ArgumentError(
        'authenticationMode requires anti-spoofing but '
        'enableAntiSpoofing is false. Either enable anti-spoofing or '
        'choose a less strict authenticationMode.',
      );
    }
    if (authenticationMode != FaceAuthenticationMode.faceOnly &&
        !enableLiveness) {
      throw ArgumentError(
        'authenticationMode requires liveness but enableLiveness is '
        'false.',
      );
    }
  }

  void _requireUnitRange(double value, String name) {
    if (value < 0.0 || value > 1.0) {
      throw ArgumentError('$name must be in [0.0, 1.0], got $value.');
    }
  }

  FaceBiometricConfig copyWith({
    double? recognitionThreshold,
    double? livenessThreshold,
    double? antiSpoofThreshold,
    bool? enableLiveness,
    bool? enableAntiSpoofing,
    FaceAuthenticationMode? authenticationMode,
    bool? captureFaceImage,
    Duration? sessionTimeout,
    Duration? challengeTimeout,
    bool? randomizeChallenges,
    List<LivenessChallenge>? challenges,
    bool? requireSingleFace,
    bool? requireCenteredFace,
    double? minimumFaceSize,
    double? maximumFaceSize,
    bool? mirrorPreview,
    bool? enableDebugLogs,
    String? embeddingModelAssetPath,
    String? antiSpoofModelAssetPath,
    int? embeddingDimension,
  }) {
    return FaceBiometricConfig(
      recognitionThreshold: recognitionThreshold ?? this.recognitionThreshold,
      livenessThreshold: livenessThreshold ?? this.livenessThreshold,
      antiSpoofThreshold: antiSpoofThreshold ?? this.antiSpoofThreshold,
      enableLiveness: enableLiveness ?? this.enableLiveness,
      enableAntiSpoofing: enableAntiSpoofing ?? this.enableAntiSpoofing,
      authenticationMode: authenticationMode ?? this.authenticationMode,
      captureFaceImage: captureFaceImage ?? this.captureFaceImage,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      challengeTimeout: challengeTimeout ?? this.challengeTimeout,
      randomizeChallenges: randomizeChallenges ?? this.randomizeChallenges,
      challenges: challenges ?? this.challenges,
      requireSingleFace: requireSingleFace ?? this.requireSingleFace,
      requireCenteredFace: requireCenteredFace ?? this.requireCenteredFace,
      minimumFaceSize: minimumFaceSize ?? this.minimumFaceSize,
      maximumFaceSize: maximumFaceSize ?? this.maximumFaceSize,
      mirrorPreview: mirrorPreview ?? this.mirrorPreview,
      enableDebugLogs: enableDebugLogs ?? this.enableDebugLogs,
      embeddingModelAssetPath:
          embeddingModelAssetPath ?? this.embeddingModelAssetPath,
      antiSpoofModelAssetPath:
          antiSpoofModelAssetPath ?? this.antiSpoofModelAssetPath,
      embeddingDimension: embeddingDimension ?? this.embeddingDimension,
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'recognitionThreshold': recognitionThreshold,
        'livenessThreshold': livenessThreshold,
        'antiSpoofThreshold': antiSpoofThreshold,
        'enableLiveness': enableLiveness,
        'enableAntiSpoofing': enableAntiSpoofing,
        'authenticationMode': authenticationMode.name,
        'captureFaceImage': captureFaceImage,
        'sessionTimeoutMs': sessionTimeout.inMilliseconds,
        'challengeTimeoutMs': challengeTimeout.inMilliseconds,
        'randomizeChallenges': randomizeChallenges,
        'challenges': challenges.map((LivenessChallenge c) => c.name).toList(),
        'requireSingleFace': requireSingleFace,
        'requireCenteredFace': requireCenteredFace,
        'minimumFaceSize': minimumFaceSize,
        'maximumFaceSize': maximumFaceSize,
        'mirrorPreview': mirrorPreview,
        'enableDebugLogs': enableDebugLogs,
        'embeddingModelAssetPath': embeddingModelAssetPath,
        'antiSpoofModelAssetPath': antiSpoofModelAssetPath,
        'embeddingDimension': embeddingDimension,
      };
}
