import Foundation

nonisolated enum VaultCredentialCodec {
    static func decode(_ data: Data) throws -> (credential: GitHubCredential, isLegacy: Bool) {
        let credential: GitHubCredential
        let isLegacy = data.first != UInt8(ascii: "{")
        if isLegacy {
            guard let token = String(data: data, encoding: .utf8) else { throw invalidCredential }
            credential = GitHubCredential(accessToken: token)
        } else {
            do { credential = try JSONDecoder().decode(GitHubCredential.self, from: data) }
            catch { throw invalidCredential }
        }
        try validate(credential)
        return (credential, isLegacy)
    }

    static func encode(_ credential: GitHubCredential) throws -> Data {
        try validate(credential)
        return try JSONEncoder().encode(credential)
    }

    static func validate(_ credential: GitHubCredential) throws {
        guard validToken(credential.accessToken),
              credential.refreshToken.map(validToken) ?? true,
              credential.expiresAt?.timeIntervalSince1970.isFinite ?? true,
              credential.refreshExpiresAt?.timeIntervalSince1970.isFinite ?? true,
              credential.expiresAt == nil || credential.refreshToken != nil,
              credential.refreshExpiresAt == nil || credential.refreshToken != nil
        else { throw invalidCredential }
    }

    private static func validToken(_ token: String) -> Bool {
        !token.isEmpty && token.utf8.count <= 4096 && token.unicodeScalars
            .allSatisfy { (33 ... 126).contains($0.value) }
    }

    private static var invalidCredential: VaultError {
        .invalid("The saved GitHub credential is invalid. Reconnect GitHub; your local records are unchanged.")
    }
}
