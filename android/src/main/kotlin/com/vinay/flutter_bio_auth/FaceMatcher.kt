package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import kotlin.math.sqrt

/**
 * Cosine similarity for 1:1 face matching.
 *
 * MUST stay numerically identical to `FaceMatcher` in
 * lib/src/face_matcher.dart (and its iOS Swift counterpart) -- that
 * Dart class's unit tests are the pinned reference for this formula.
 */
class FaceMatcher {

    data class MatchResult(val isMatch: Boolean, val similarity: Double, val threshold: Double)

    fun cosineSimilarity(a: FloatArray, b: FloatArray): Double {
        if (a.isEmpty() || b.isEmpty()) {
            throw BiometricException(FaceBiometricErrorCode.embeddingGenerationFailed, "Embeddings must not be empty.")
        }
        if (a.size != b.size) {
            throw BiometricException(
                FaceBiometricErrorCode.embeddingGenerationFailed,
                "Embedding dimension mismatch: ${a.size} vs ${b.size}.",
            )
        }
        var dot = 0.0
        var normA = 0.0
        var normB = 0.0
        for (i in a.indices) {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        if (normA == 0.0 || normB == 0.0) return 0.0
        val similarity = dot / (sqrt(normA) * sqrt(normB))
        return similarity.coerceIn(-1.0, 1.0)
    }

    fun match(a: FloatArray, b: FloatArray, threshold: Double): MatchResult {
        val similarity = cosineSimilarity(a, b)
        return MatchResult(isMatch = similarity >= threshold, similarity = similarity, threshold = threshold)
    }
}
