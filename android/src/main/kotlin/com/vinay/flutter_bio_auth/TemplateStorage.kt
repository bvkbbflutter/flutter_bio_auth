package com.vinay.flutter_bio_auth

import android.content.Context
import android.content.SharedPreferences
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import com.vinay.flutter_bio_auth.model.FaceTemplateNative
import org.json.JSONArray
import org.json.JSONObject

/**
 * Storage abstraction so the recognition/authentication engines are
 * never coupled to a specific persistence mechanism. The plugin ships
 * [SharedPreferencesTemplateStorage] as the default/example
 * implementation; a production app can swap in its own (Room,
 * server-backed, etc.) by implementing this interface and wiring it
 * into [FaceBiometricPlugin] instead.
 */
interface BiometricTemplateStorage {
    fun save(userId: String, template: FaceTemplateNative)
    fun get(userId: String): FaceTemplateNative?
    fun exists(userId: String): Boolean
    fun delete(userId: String)
    fun getUsers(): List<String>
    fun clear()
}

/**
 * Default local storage. Stores ONLY the AES-GCM-encrypted template
 * payload (see [CryptoManager]) plus non-sensitive metadata
 * (userId/version/createdAt/modelVersion/embeddingDimension) as a
 * Base64 blob per user, under key `face_template_<userId>`. The
 * encryption key itself never enters SharedPreferences -- it lives
 * only in the Android Keystore.
 */
class SharedPreferencesTemplateStorage(
    context: Context,
    private val crypto: CryptoManager,
) : BiometricTemplateStorage {

    private val prefs: SharedPreferences =
        context.getSharedPreferences("flutter_bio_auth_templates", Context.MODE_PRIVATE)

    private val usersIndexKey = "flutter_bio_auth_user_index"

    private fun keyFor(userId: String) = "face_template_$userId"

    override fun save(userId: String, template: FaceTemplateNative) {
        try {
            val embeddingJson = JSONArray().apply {
                template.embedding.forEach { put(it.toDouble()) }
            }
            val plaintext = JSONObject().apply {
                put("version", template.version)
                put("modelVersion", template.modelVersion)
                put("embeddingDimension", template.embeddingDimension)
                put("embedding", embeddingJson)
                put("createdAtEpochMillis", template.createdAtEpochMillis)
            }.toString()

            val encrypted = crypto.encrypt(plaintext.toByteArray(Charsets.UTF_8))

            val metadata = JSONObject().apply {
                put("userId", userId)
                put("version", template.version)
                put("modelVersion", template.modelVersion)
                put("embeddingDimension", template.embeddingDimension)
                put("createdAtEpochMillis", template.createdAtEpochMillis)
                put("encryptedTemplate", encrypted)
            }

            prefs.edit()
                .putString(keyFor(userId), metadata.toString())
                .apply()
            addToIndex(userId)
        } catch (e: BiometricException) {
            throw e
        } catch (e: Exception) {
            throw BiometricException(FaceBiometricErrorCode.storageError, "Failed to save the template for '$userId'.", e)
        }
    }

    override fun get(userId: String): FaceTemplateNative? {
        val raw = prefs.getString(keyFor(userId), null) ?: return null
        return try {
            val metadata = JSONObject(raw)
            val encrypted = metadata.getString("encryptedTemplate")
            val plaintextBytes = crypto.decrypt(encrypted)
            val plaintext = JSONObject(String(plaintextBytes, Charsets.UTF_8))

            val embeddingArray = plaintext.getJSONArray("embedding")
            val embedding = FloatArray(embeddingArray.length()) { i -> embeddingArray.getDouble(i).toFloat() }

            FaceTemplateNative(
                version = plaintext.getInt("version"),
                modelVersion = plaintext.getString("modelVersion"),
                embeddingDimension = plaintext.getInt("embeddingDimension"),
                embedding = embedding,
                createdAtEpochMillis = plaintext.getLong("createdAtEpochMillis"),
            )
        } catch (e: BiometricException) {
            throw e
        } catch (e: Exception) {
            throw BiometricException(
                FaceBiometricErrorCode.storageError,
                "Stored template for '$userId' is corrupted or unreadable.",
                e,
            )
        }
    }

    override fun exists(userId: String): Boolean = prefs.contains(keyFor(userId))

    override fun delete(userId: String) {
        prefs.edit().remove(keyFor(userId)).apply()
        removeFromIndex(userId)
    }

    override fun getUsers(): List<String> {
        val raw = prefs.getStringSet(usersIndexKey, emptySet()) ?: emptySet()
        return raw.toList().sorted()
    }

    override fun clear() {
        val users = getUsers()
        val editor = prefs.edit()
        users.forEach { editor.remove(keyFor(it)) }
        editor.remove(usersIndexKey)
        editor.apply()
    }

    private fun addToIndex(userId: String) {
        val current = (prefs.getStringSet(usersIndexKey, emptySet()) ?: emptySet()).toMutableSet()
        current.add(userId)
        prefs.edit().putStringSet(usersIndexKey, current).apply()
    }

    private fun removeFromIndex(userId: String) {
        val current = (prefs.getStringSet(usersIndexKey, emptySet()) ?: emptySet()).toMutableSet()
        current.remove(userId)
        prefs.edit().putStringSet(usersIndexKey, current).apply()
    }
}
