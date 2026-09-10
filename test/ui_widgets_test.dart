import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_bio_auth/src/platform/face_biometric_platform.dart';
import 'package:flutter_test/flutter_test.dart';

class MockPlatform extends FaceBiometricPlatform {
  final StreamController<FaceBiometricState> stateController =
      StreamController<FaceBiometricState>.broadcast();
  final StreamController<LivenessChallengeProgress> challengeController =
      StreamController<LivenessChallengeProgress>.broadcast();

  final Completer<LivenessResult> livenessCompleter =
      Completer<LivenessResult>();

  @override
  Stream<FaceBiometricState> get stateStream => stateController.stream;

  @override
  Stream<LivenessChallengeProgress> get challengeProgressStream =>
      challengeController.stream;

  @override
  Future<void> initialize(FaceBiometricConfig config) async {}

  @override
  Future<LivenessResult> verifyLiveness({
    List<LivenessChallenge>? challenges,
    Duration? timeout,
  }) =>
      livenessCompleter.future;

  @override
  Future<FaceEnrollmentResult> enroll({required String userId}) async {
    return FaceEnrollmentResult(
      success: true,
      userId: 'test',
      samplesUsed: 5,
      duration: Duration(seconds: 2),
    );
  }

  @override
  Future<FaceAuthenticationResult> authenticate(
      {required String userId}) async {
    return FaceAuthenticationResult(
      userId: userId,
      authenticated: true,
      similarity: 0.95,
      livenessScore: 0.92,
      antiSpoofScore: 0.98,
      duration: Duration(seconds: 1),
    );
  }

  @override
  Future<FaceMatchResult> compare({
    required dynamic firstImage,
    required dynamic secondImage,
  }) async =>
      throw UnimplementedError();

  @override
  Future<bool> isEnrolled({required String userId}) async => true;

  @override
  Future<List<String>> getEnrolledUsers() async => <String>['user1'];

  @override
  Future<void> deleteEnrollment({required String userId}) async {}

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
  Future<void> dispose() async {}
}

void main() {
  late MockPlatform mockPlatform;

  setUp(() async {
    mockPlatform = MockPlatform();
    FaceBiometricPlatform.instance = mockPlatform;
    await FaceBiometric.initialize(config: const FaceBiometricConfig());
  });

  group('Turnkey UI Widgets', () {
    testWidgets('FaceCutoutOverlay renders without throwing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: FaceCutoutOverlay(
              state: FaceBiometricState.detectingFace,
            ),
          ),
        ),
      );

      expect(find.byType(FaceCutoutOverlay), findsOneWidget);
    });

    testWidgets('FaceBiometricScanner displays title and timer badge',
        (WidgetTester tester) async {
      final FaceBiometricController controller = FaceBiometricController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceBiometricScanner(
              controller: controller,
              title: 'Custom Title Here',
              timeoutSeconds: 30,
              showTimer: true,
            ),
          ),
        ),
      );

      expect(find.text('Custom Title Here'), findsOneWidget);
      expect(find.text('00:30'), findsOneWidget);

      controller.dispose();
    });

    testWidgets('FaceSmileView starts and displays smile scanner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceSmileView(
              title: 'Smile to unlock',
              onSmiled: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Smile to unlock'), findsOneWidget);
      expect(find.byType(FaceBiometricScanner), findsOneWidget);
    });

    testWidgets(
        'FaceLivenessView starts in running state with FaceBiometricScanner',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FaceLivenessView(
              timeout: const Duration(seconds: 15),
            ),
          ),
        ),
      );

      expect(find.byType(FaceBiometricScanner), findsOneWidget);
      expect(find.text('Fit face inside the oval'), findsOneWidget);
      expect(find.text('00:15'), findsOneWidget);
    });
  });
}
