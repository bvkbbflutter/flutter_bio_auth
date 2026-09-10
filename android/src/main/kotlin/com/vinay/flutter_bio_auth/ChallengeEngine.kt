package com.vinay.flutter_bio_auth

import com.vinay.flutter_bio_auth.model.LivenessChallenge
import kotlin.random.Random

/**
 * Builds the ordered challenge list for one session. Logic
 * intentionally mirrors lib/src/challenge_sequencer.dart exactly
 * (dedupe preserving first-seen order, then optional shuffle) so
 * behavior is consistent regardless of which layer a future
 * refactor moves this into.
 */
class ChallengeEngine(private val random: Random = Random.Default) {

    fun buildSequence(pool: List<LivenessChallenge>, randomize: Boolean): List<LivenessChallenge> {
        if (pool.isEmpty()) return emptyList()
        val deduped = LinkedHashSet(pool).toList()
        if (!randomize) return deduped
        return deduped.shuffled(random)
    }
}
