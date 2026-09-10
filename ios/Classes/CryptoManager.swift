import CryptoKit
import Foundation
import Security

/// Encrypts/decrypts biometric templates with AES-256-GCM, where the
/// symmetric key material lives only in the iOS Keychain (with
/// `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, so it never
/// leaves the device via backup/iCloud) and never enters UserDefaults
/// as exportable bytes. UserDefaults only ever sees ciphertext.
///
/// If Keychain access fails, this fails closed via
/// `BiometricException` rather than falling back to plaintext.
final class CryptoManager {
    private let keyTag = "com.vinay.flutter_bio_auth.template_key"

    private func getOrCreateKey() throws -> SymmetricKey {
        if let existing = try readKeyFromKeychain() { return existing }

        let newKey = SymmetricKey(size: .bits256)
        try saveKeyToKeychain(newKey)
        return newKey
    }

    private func readKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw BiometricException(.encryptionError, "Failed to read the template encryption key from the Keychain.")
        }
        return SymmetricKey(data: data)
    }

    private func saveKeyToKeychain(_ key: SymmetricKey) throws {
        let keyData = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyTag,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemDelete(query as CFDictionary) // ensure no stale duplicate
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BiometricException(.encryptionError, "Failed to store the template encryption key in the Keychain.")
        }
    }

    /// Returns Base64(nonce || ciphertext || tag).
    func encrypt(_ plaintext: Data) throws -> String {
        do {
            let key = try getOrCreateKey()
            let sealed = try AES.GCM.seal(plaintext, using: key)
            guard let combined = sealed.combined else {
                throw BiometricException(.encryptionError, "Failed to produce combined ciphertext.")
            }
            return combined.base64EncodedString()
        } catch let error as BiometricException {
            throw error
        } catch {
            throw BiometricException(.encryptionError, "Template encryption failed.", underlying: error)
        }
    }

    func decrypt(_ base64Combined: String) throws -> Data {
        do {
            guard let combined = Data(base64Encoded: base64Combined) else {
                throw BiometricException(.templateDecryptionFailed, "Stored template is not valid Base64.")
            }
            let key = try getOrCreateKey()
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            return try AES.GCM.open(sealedBox, using: key)
        } catch let error as BiometricException {
            throw error
        } catch {
            throw BiometricException(
                .templateDecryptionFailed,
                "Failed to decrypt the stored template. It may be corrupted or was encrypted by a different device/key.",
                underlying: error
            )
        }
    }
}
