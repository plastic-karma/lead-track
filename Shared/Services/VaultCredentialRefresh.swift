import Foundation

@MainActor
enum VaultCredentialRefresh {
    static func resolve(
        _ credential: GitHubCredential,
        using refresh: @escaping @Sendable (GitHubCredential) async throws -> GitHubCredential,
        persist: (GitHubCredential) throws -> Void,
        now: Date = Date()
    ) async throws -> GitHubCredential {
        try Task.checkCancellation()
        guard let expiry = credential.expiresAt, expiry <= now.addingTimeInterval(60) else { return credential }

        // Refresh rotates both tokens. Finish and persist it even if foreground sync is cancelled;
        // disconnect waits for that sync before deleting the Keychain item.
        let rotation = Task { try await refresh(credential) }
        let replacement = try await rotation.value
        try persist(replacement)
        try Task.checkCancellation()
        return replacement
    }
}
