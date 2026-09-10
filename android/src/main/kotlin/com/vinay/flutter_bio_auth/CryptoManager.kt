package com.vinay.flutter_bio_auth

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import com.vinay.flutter_bio_auth.model.BiometricException
import com.vinay.flutter_bio_auth.model.FaceBiometricErrorCode
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import android.util.Base64

/**
 * Encrypts/decrypts biometric templates with AES-256-GCM, where the
 * key itself lives only in the Android Keystore (hardware-backed on
 * most devices) and never touches SharedPreferences or app memory as
 * exportable bytes. SharedPreferences only ever sees the resulting
 * ciphertext.
 *
 * If Keystore key generation/access fails (some very old/broken
 * devices), this fails closed via [BiometricException] rather than
 * falling back to storing plaintext biometric data.
 */
class CryptoManager {

    companion object {
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val KEY_ALIAS = "flutter_bio_auth_template_key"
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private const val GCM_TAG_LENGTH_BITS = 128
        private const val GCM_IV_LENGTH_BYTES = 12
    }

    private val keyStore: KeyStore by lazy {
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
    }

    private fun getOrCreateKey(): SecretKey {
        try {
            val existing = keyStore.getKey(KEY_ALIAS, null) as? SecretKey
            if (existing != null) return existing

            val keyGenerator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE,
            )
            val spec = KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                .build()
            keyGenerator.init(spec)
            return keyGenerator.generateKey()
        } catch (e: Exception) {
            throw BiometricException(
                FaceBiometricErrorCode.encryptionError,
                "Failed to obtain a template encryption key from the Android Keystore.",
                e,
            )
        }
    }

    /** Returns Base64(iv || ciphertext || tag). */
    fun encrypt(plaintext: ByteArray): String {
        try {
            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
            val iv = cipher.iv
            val ciphertext = cipher.doFinal(plaintext)
            val combined = ByteArray(iv.size + ciphertext.size)
            System.arraycopy(iv, 0, combined, 0, iv.size)
            System.arraycopy(ciphertext, 0, combined, iv.size, ciphertext.size)
            return Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (e: BiometricException) {
            throw e
        } catch (e: Exception) {
            throw BiometricException(FaceBiometricErrorCode.encryptionError, "Template encryption failed.", e)
        }
    }

    fun decrypt(base64Combined: String): ByteArray {
        try {
            val combined = Base64.decode(base64Combined, Base64.NO_WRAP)
            if (combined.size <= GCM_IV_LENGTH_BYTES) {
                throw IllegalArgumentException("Ciphertext too short to contain an IV.")
            }
            val iv = combined.copyOfRange(0, GCM_IV_LENGTH_BYTES)
            val ciphertext = combined.copyOfRange(GCM_IV_LENGTH_BYTES, combined.size)

            val cipher = Cipher.getInstance(TRANSFORMATION)
            cipher.init(Cipher.DECRYPT_MODE, getOrCreateKey(), GCMParameterSpec(GCM_TAG_LENGTH_BITS, iv))
            return cipher.doFinal(ciphertext)
        } catch (e: Exception) {
            throw BiometricException(
                FaceBiometricErrorCode.templateDecryptionFailed,
                "Failed to decrypt the stored template. It may be corrupted or " +
                    "was encrypted by a different device/key.",
                e,
            )
        }
    }
}
