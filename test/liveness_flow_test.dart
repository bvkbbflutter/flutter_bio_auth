import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_bio_auth/src/platform/face_biometric_platform.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFaceBiometricPlatform extends FaceBiometricPlatform {
  final StreamController<FaceBiometricState> stateController =
      StreamController<FaceBiometricState>.broadcast();
  final StreamController<LivenessChallengeProgress> challengeController =
      StreamController<LivenessChallengeProgress>.broadcast();

  bool initialized = false;
  bool verifyLivenessCalled = false;
  List<LivenessChallenge>? lastChallenges;

  @override
  Stream<FaceBiometricState> get stateStream => stateController.stream;

  @override
  Stream<LivenessChallengeProgress> get challengeProgressStream =>
      challengeController.stream;

  @override
  Future<void> initialize(FaceBiometricConfig config) async {
    initialized = true;
  }

  @override
  Future<LivenessResult> verifyLiveness({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
  }) async {
    verifyLivenessCalled = true;
    lastChallenges = challenges;
    return const LivenessResult(
      passed: true,
      overallScore: 1.0,
      completedChallenges: <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.smile,
      ],
      failedChallenge: null,
    );
  }

  @override
  Future<FaceEnrollmentResult> enroll({
    required String userId,
    bool? enableLiveness,
  }) async =>
      throw UnimplementedError();

  @override
  Future<FaceAuthenticationResult> authenticate({
    required String userId,
    bool? enableLiveness,
  }) async =>
      throw UnimplementedError();

  @override
  Stream<Map<String, dynamic>> get detectionStream =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<void> startFaceDetection() async {}

  @override
  Future<void> stopFaceDetection() async {}

  @override
  Future<void> switchModel({
    required String? assetPath,
    int embeddingDimension = 192,
    String modelVersion = 'face-model-1',
    double threshold = 0.68,
  }) async {}

  @override
  Future<FaceMatchResult> compare({
    required Uint8List firstImage,
    required Uint8List secondImage,
  }) async =>
      throw UnimplementedError();

  @override
  Future<bool> isEnrolled({required String userId}) async => false;

  @override
  Future<void> deleteEnrollment({required String userId}) async {}

  @override
  Future<List<String>> getEnrolledUsers() async => <String>[];

  @override
  Future<void> clearAllEnrollments() async {}

  @override
  Future<bool> authenticateWithDeviceBiometrics({
    String? reason,
    DeviceAuthType authType = DeviceAuthType.biometricOnly,
  }) async =>
      true;

  @override
  Future<void> retry() async {}

  @override
  Future<void> dispose() async {
    await stateController.close();
    await challengeController.close();
  }
}

void main() {
  group('FaceBiometricController and Liveness Verification Flow', () {
    late FakeFaceBiometricPlatform fakePlatform;

    setUp(() {
      fakePlatform = FakeFaceBiometricPlatform();
      FaceBiometricPlatform.instance = fakePlatform;
    });

    test('controller forwards stateStream events from platform', () async {
      final FaceBiometricController controller =
          FaceBiometricController(platform: fakePlatform);
      final List<FaceBiometricState> states = <FaceBiometricState>[];
      final StreamSubscription<FaceBiometricState> sub =
          controller.stateStream.listen(states.add);

      fakePlatform.stateController.add(FaceBiometricState.initializing);
      fakePlatform.stateController.add(FaceBiometricState.cameraReady);
      fakePlatform.stateController.add(FaceBiometricState.runningLiveness);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, <FaceBiometricState>[
        FaceBiometricState.initializing,
        FaceBiometricState.cameraReady,
        FaceBiometricState.runningLiveness,
      ]);

      await sub.cancel();
      await controller.dispose();
    });

    test('controller exposes challengeProgressStream', () async {
      final FaceBiometricController controller =
          FaceBiometricController(platform: fakePlatform);
      final List<LivenessChallengeProgress> progressList =
          <LivenessChallengeProgress>[];
      final StreamSubscription<LivenessChallengeProgress> sub =
          controller.challengeProgressStream.listen(progressList.add);

      const LivenessChallengeProgress item = LivenessChallengeProgress(
        challenge: LivenessChallenge.blink,
        instruction: 'Blink both eyes',
        progress: 0.5,
        confidence: 0.8,
        completed: false,
        timedOut: false,
      );
      fakePlatform.challengeController.add(item);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(progressList.length, 1);
      expect(progressList.first.challenge, LivenessChallenge.blink);
      expect(progressList.first.progress, 0.5);

      await sub.cancel();
      await controller.dispose();
    });

    test('verifyLiveness invokes platform method and returns LivenessResult',
        () async {
      await FaceBiometric.initialize();
      final LivenessResult result = await FaceBiometric.verifyLiveness(
        challenges: const <LivenessChallenge>[
          LivenessChallenge.blink,
          LivenessChallenge.smile,
        ],
      );

      expect(fakePlatform.verifyLivenessCalled, isTrue);
      expect(fakePlatform.lastChallenges, <LivenessChallenge>[
        LivenessChallenge.blink,
        LivenessChallenge.smile,
      ]);
      expect(result.passed, isTrue);
      expect(result.overallScore, 1.0);
      expect(result.completedChallenges.length, 2);
    });
  });
}
