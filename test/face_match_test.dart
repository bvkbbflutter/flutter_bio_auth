import 'package:flutter_bio_auth/flutter_bio_auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const FaceMatcher matcher = FaceMatcher();

  group('FaceMatcher.cosineSimilarity', () {
    test('identical embeddings yield similarity 1.0', () {
      final List<double> a = <double>[0.2, 0.4, 0.4, 0.8];
      expect(matcher.cosineSimilarity(a, List<double>.from(a)),
          closeTo(1.0, 1e-9));
    });

    test('opposite embeddings yield similarity -1.0', () {
      final List<double> a = <double>[1.0, 0.0, 0.0];
      final List<double> b = <double>[-1.0, 0.0, 0.0];
      expect(matcher.cosineSimilarity(a, b), closeTo(-1.0, 1e-9));
    });

    test('orthogonal embeddings yield similarity 0.0', () {
      final List<double> a = <double>[1.0, 0.0];
      final List<double> b = <double>[0.0, 1.0];
      expect(matcher.cosineSimilarity(a, b), closeTo(0.0, 1e-9));
    });

    test('similar-but-not-identical embeddings yield a high similarity', () {
      final List<double> a = <double>[0.10, 0.20, 0.30, 0.40];
      final List<double> b = <double>[0.11, 0.19, 0.31, 0.39];
      final double similarity = matcher.cosineSimilarity(a, b);
      expect(similarity, greaterThan(0.99));
      expect(similarity, lessThan(1.0));
    });

    test('dissimilar embeddings yield a low similarity', () {
      final List<double> a = <double>[1.0, 0.0, 0.0, 0.0];
      final List<double> b = <double>[0.0, 0.0, 0.0, 1.0];
      expect(matcher.cosineSimilarity(a, b), closeTo(0.0, 1e-9));
    });

    test('a zero vector returns 0.0 rather than dividing by zero', () {
      final List<double> a = <double>[0.0, 0.0, 0.0];
      final List<double> b = <double>[1.0, 2.0, 3.0];
      expect(matcher.cosineSimilarity(a, b), 0.0);
    });

    test('empty embeddings throw ArgumentError', () {
      expect(
        () => matcher.cosineSimilarity(<double>[], <double>[]),
        throwsArgumentError,
      );
    });

    test('mismatched dimensions throw ArgumentError', () {
      expect(
        () => matcher.cosineSimilarity(<double>[1.0, 2.0], <double>[1.0]),
        throwsArgumentError,
      );
    });
  });

  group('FaceMatcher.match', () {
    test('similarity above threshold is a match', () {
      final List<double> a = <double>[1.0, 0.0];
      final List<double> b = <double>[1.0, 0.0];
      final FaceMatchResult result = matcher.match(a, b, threshold: 0.82);
      expect(result.isMatch, isTrue);
      expect(result.similarity, closeTo(1.0, 1e-9));
      expect(result.threshold, 0.82);
    });

    test('similarity below threshold is not a match', () {
      final List<double> a = <double>[1.0, 0.0];
      final List<double> b = <double>[0.0, 1.0];
      final FaceMatchResult result = matcher.match(a, b, threshold: 0.82);
      expect(result.isMatch, isFalse);
    });

    test('similarity exactly at threshold counts as a match (inclusive)', () {
      // Constructed so cosineSimilarity(a, b) == 0.8 exactly.
      final List<double> a = <double>[1.0, 0.0];
      final List<double> b = <double>[0.8, 0.6];
      final double similarity = matcher.cosineSimilarity(a, b);
      final FaceMatchResult result = matcher.match(a, b, threshold: similarity);
      expect(result.isMatch, isTrue);
    });
  });
}
