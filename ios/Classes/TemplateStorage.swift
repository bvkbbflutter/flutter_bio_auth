import Foundation

/// Storage abstraction so the recognition/authentication engines are
/// never coupled to a specific persistence mechanism, mirrors
/// TemplateStorage.kt's BiometricTemplateStorage.
protocol BiometricTemplateStorage: AnyObject {
    func save(userId: String, template: FaceTemplateNative) throws
    func get(userId: String) throws -> FaceTemplateNative?
    func exists(userId: String) -> Bool
    func delete(userId: String)
    func getUsers() -> [String]
    func clear()
}

/// Default local storage. Stores ONLY the AES-GCM-encrypted payload
/// (see CryptoManager) plus non-sensitive metadata, as JSON under key
/// `face_template_<userId>` in `UserDefaults`. The encryption key
/// itself never enters UserDefaults -- it lives only in the Keychain.
final class UserDefaultsTemplateStorage: BiometricTemplateStorage {
    private let defaults = UserDefaults.standard
    private let crypto: CryptoManager
    private let usersIndexKey = "flutter_bio_auth_user_index"

    init(crypto: CryptoManager) {
        self.crypto = crypto
    }

    private func key(for userId: String) -> String { "face_template_\(userId)" }

    func save(userId: String, template: FaceTemplateNative) throws {
        let plaintextDict: [String: Any] = [
            "version": template.version,
            "modelVersion": template.modelVersion,
            "embeddingDimension": template.embeddingDimension,
            "embedding": template.embedding.map { Double($0) },
            "createdAtEpochMillis": template.createdAtEpochMillis,
        ]
        guard let plaintextData = try? JSONSerialization.data(withJSONObject: plaintextDict) else {
            throw BiometricException(.storageError, "Failed to serialize the template for '\(userId)'.")
        }
        let encrypted = try crypto.encrypt(plaintextData)

        let metadata: [String: Any] = [
            "userId": userId,
            "version": template.version,
            "modelVersion": template.modelVersion,
            "embeddingDimension": template.embeddingDimension,
            "createdAtEpochMillis": template.createdAtEpochMillis,
            "encryptedTemplate": encrypted,
        ]
        guard let metadataData = try? JSONSerialization.data(withJSONObject: metadata) else {
            throw BiometricException(.storageError, "Failed to serialize template metadata for '\(userId)'.")
        }
        defaults.set(metadataData, forKey: key(for: userId))
        addToIndex(userId)
    }

    func get(userId: String) throws -> FaceTemplateNative? {
        guard let metadataData = defaults.data(forKey: key(for: userId)) else { return nil }
        guard let metadata = try? JSONSerialization.jsonObject(with: metadataData) as? [String: Any],
              let encrypted = metadata["encryptedTemplate"] as? String else {
            throw BiometricException(.storageError, "Stored template for '\(userId)' is corrupted or unreadable.")
        }
        let plaintextData = try crypto.decrypt(encrypted)
        guard let plaintext = try? JSONSerialization.jsonObject(with: plaintextData) as? [String: Any],
              let version = plaintext["version"] as? Int,
              let modelVersion = plaintext["modelVersion"] as? String,
              let dimension = plaintext["embeddingDimension"] as? Int,
              let embeddingDoubles = plaintext["embedding"] as? [Double],
              let createdAt = plaintext["createdAtEpochMillis"] as? Int64 else {
            throw BiometricException(.storageError, "Stored template for '\(userId)' is corrupted or unreadable.")
        }
        return FaceTemplateNative(
            version: version, modelVersion: modelVersion, embeddingDimension: dimension,
            embedding: embeddingDoubles.map { Float($0) }, createdAtEpochMillis: createdAt
        )
    }

    func exists(userId: String) -> Bool { defaults.data(forKey: key(for: userId)) != nil }

    func delete(userId: String) {
        defaults.removeObject(forKey: key(for: userId))
        removeFromIndex(userId)
    }

    func getUsers() -> [String] {
        (defaults.array(forKey: usersIndexKey) as? [String] ?? []).sorted()
    }

    func clear() {
        for user in getUsers() { defaults.removeObject(forKey: key(for: user)) }
        defaults.removeObject(forKey: usersIndexKey)
    }

    private func addToIndex(_ userId: String) {
        var current = Set(defaults.array(forKey: usersIndexKey) as? [String] ?? [])
        current.insert(userId)
        defaults.set(Array(current), forKey: usersIndexKey)
    }

    private func removeFromIndex(_ userId: String) {
        var current = Set(defaults.array(forKey: usersIndexKey) as? [String] ?? [])
        current.remove(userId)
        defaults.set(Array(current), forKey: usersIndexKey)
    }
}
