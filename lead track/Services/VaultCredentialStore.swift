import Foundation
import Security

enum VaultCredentialStore {
    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "plastickarma.lead-track.obsidian",
            kSecAttrAccount as String: "github-token",
            kSecAttrSynchronizable as String: false
        ]
    }

    static func load() throws -> GitHubCredential? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultError
                .invalid("The GitHub token could not be read from Keychain. Unlock the device and try again.")
        }
        let decoded = try VaultCredentialCodec.decode(data)
        if decoded.isLegacy { try save(decoded.credential) }
        return decoded.credential
    }

    static func save(_ credential: GitHubCredential) throws {
        let attributes: [String: Any] = try [
            kSecValueData as String: VaultCredentialCodec.encode(credential),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let item = query.merging(attributes) { _, value in value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw storageError }
        } else if status != errSecSuccess {
            throw storageError
        }
    }

    static func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw storageError }
    }

    private static var storageError: VaultError {
        .invalid("The GitHub token could not be updated in Keychain. Your local records are unchanged.")
    }
}
