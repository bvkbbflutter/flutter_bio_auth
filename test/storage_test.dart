import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FaceTemplate', () {
    final DateTime now = DateTime.utc(2026, 1, 1);

    FaceTemplate buildTemplate({
      int dimension = 4,
      String modelVersion = 'face-model-1',
    }) {
      return FaceTemplate(
        version: FaceTemplate.currentTemplateVersion,
        modelVersion: modelVersion,
        embeddingDimension: dimension,
        embedding: List<double>.filled(dimension, 0.5),
        createdAt: now,
      );
    }

    test('round-trips through toMap/fromMap', () {
      final FaceTemplate original = buildTemplate();
      final FaceTemplate restored = FaceTemplate.fromMap(original.toMap());

      expect(restored.version, original.version);
      expect(restored.modelVersion, original.modelVersion);
      expect(restored.embeddingDimension, original.embeddingDimension);
      expect(restored.embedding, original.embedding);
      expect(restored.createdAt, original.createdAt);
    });

    test('isCompatibleWith matches identical model version and dimension', () {
      final FaceTemplate template = buildTemplate();
      expect(
        template.isCompatibleWith(
          expectedModelVersion: 'face-model-1',
          expectedDimension: 4,
        ),
        isTrue,
      );
    });

    test('isCompatibleWith rejects a different model version', () {
      final FaceTemplate template = buildTemplate(modelVersion: 'face-model-1');
      expect(
        template.isCompatibleWith(
          expectedModelVersion: 'face-model-2',
          expectedDimension: 4,
        ),
        isFalse,
      );
    });

    test('isCompatibleWith rejects a different dimension', () {
      final FaceTemplate template = buildTemplate(dimension: 4);
      expect(
        template.isCompatibleWith(
          expectedModelVersion: 'face-model-1',
          expectedDimension: 512,
        ),
        isFalse,
      );
    });
  });
}
