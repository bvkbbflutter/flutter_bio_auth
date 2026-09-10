import Foundation

/// Cosine similarity for 1:1 face matching. MUST stay numerically
/// identical to lib/src/face_matcher.dart and FaceMatcher.kt.
final class FaceMatcher {
    struct MatchResult {
        let isMatch: Bool
        let similarity: Double
        let threshold: Double
    }

    func cosineSimilarity(_ a: [Float], _ b: [Float]) throws -> Double {
        guard !a.isEmpty, !b.isEmpty else {
            throw BiometricException(.embeddingGenerationFailed, "Embeddings must not be empty.")
        }
        guard a.count == b.count else {
            throw BiometricException(.embeddingGenerationFailed, "Embedding dimension mismatch: \(a.count) vs \(b.count).")
        }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += Double(a[i]) * Double(b[i])
            normA += Double(a[i]) * Double(a[i])
            normB += Double(b[i]) * Double(b[i])
        }
        guard normA != 0.0, normB != 0.0 else { return 0.0 }
        let similarity = dot / (sqrt(normA) * sqrt(normB))
        return min(1.0, max(-1.0, similarity))
    }

    func match(_ a: [Float], _ b: [Float], threshold: Double) throws -> MatchResult {
        let similarity = try cosineSimilarity(a, b)
        return MatchResult(isMatch: similarity >= threshold, similarity: similarity, threshold: threshold)
    }
}
