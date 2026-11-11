import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bio_auth/flutter_bio_auth.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FaceAI Modular Facade & Subsystems', () {
    test('FaceAI static services are exposed and non-null', () {
      expect(FaceAI.auth, isNotNull);
      expect(FaceAI.recognition, isNotNull);
      expect(FaceAI.expression, isNotNull);
      expect(FaceAI.liveness, isNotNull);
      expect(FaceAI.compliance, isNotNull);
      expect(FaceAI.models, isNotNull);
    });

    test('FaceAI.models registers and activates models properly', () async {
      final manager = FaceModelManager();
      final models = await manager.getAvailableModels();
      expect(models.isNotEmpty, isTrue);

      final customConfig = ModelConfig(
        id: 'arcface_custom',
        type: ModelType.faceRecognition,
        name: 'ArcFace Custom',
        source: ModelSource.asset('assets/models/arcface.tflite'),
        embeddingDimensions: 512,
        calibratedThreshold: 0.72,
      );

      await manager.register(customConfig);
      await manager.activate(ModelType.faceRecognition, modelId: 'arcface_custom');

      final active = manager.getActiveModel(ModelType.faceRecognition);
      expect(active?.id, 'arcface_custom');
      expect(active?.embeddingDimensions, 512);

      final bench = await manager.benchmark(modelId: 'arcface_custom');
      expect(bench.averageInferenceTimeMs, greaterThan(0));
    });

    test('LocalAuthResult typed properties', () {
      final success = LocalAuthResult.success();
      expect(success.isSuccess, isTrue);
      expect(success.status, LocalAuthStatus.success);

      final cancelled = LocalAuthResult.cancelled();
      expect(cancelled.isSuccess, isFalse);
      expect(cancelled.status, LocalAuthStatus.cancelled);

      final locked = LocalAuthResult.lockedOut();
      expect(locked.status, LocalAuthStatus.lockedOut);
    });

    test('ExpressionResult computation from probabilities', () {
      final smile = ExpressionResult.fromProbabilities(
        smilingProbability: 0.88,
        leftEyeOpenProbability: 0.90,
        rightEyeOpenProbability: 0.90,
      );
      expect(smile.isSmiling, isTrue);
      expect(smile.expression, FacialExpression.smile);
      expect(smile.confidence, closeTo(0.88, 0.01));

      final blink = ExpressionResult.fromProbabilities(
        smilingProbability: 0.05,
        leftEyeOpenProbability: 0.10,
        rightEyeOpenProbability: 0.12,
      );
      expect(blink.isBlinking, isTrue);
      expect(blink.expression, FacialExpression.blink);
    });

    test('DeliveryComplianceResult success and missing item evaluation', () {
      final success = DeliveryComplianceResult.success(
        faceVerified: true,
        helmetConfidence: 0.94,
        uniformConfidence: 0.91,
      );
      expect(success.isReady, isTrue);
      expect(success.missingItems.isEmpty, isTrue);
      expect(success.isWearingHelmet, isTrue);
      expect(success.isWearingUniform, isTrue);

      final missing = DeliveryComplianceResult.missing(
        missingItems: ['Helmet', 'Uniform'],
      );
      expect(missing.isReady, isFalse);
      expect(missing.missingItems, contains('Helmet'));
      expect(missing.missingItems, contains('Uniform'));
    });

    test('UniformPreset target hue ranges and brand colors', () {
      expect(UniformPreset.zeptoPurple.displayName, contains('Zepto'));
      expect(UniformPreset.zeptoPurple.targetHueRange[0], 260.0);
      expect(UniformPreset.swiggyOrange.displayName, contains('Swiggy'));
      expect(UniformPreset.zomatoRed.displayName, contains('Zomato'));
      expect(UniformPreset.blinkitYellow.displayName, contains('Blinkit'));
    });

    test('DeviceCapabilities report generation', () async {
      final caps = await FaceAI.getDeviceCapabilities();
      expect(caps.supportsBiometrics, isTrue);
      expect(caps.supportedDelegates.isNotEmpty, isTrue);
      expect(caps.availableCameras.isNotEmpty, isTrue);
    });
  });
}
