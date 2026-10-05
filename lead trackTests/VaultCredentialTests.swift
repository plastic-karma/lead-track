import Foundation
import Testing
@testable import lead_track

@Suite("Vault credential persistence")
@MainActor
struct VaultCredentialTests {
    private let now = Date(timeIntervalSince1970: 1000)
    private var expired: GitHubCredential {
        GitHubCredential(accessToken: "old-access", refreshToken: "old-refresh", expiresAt: now)
    }

    private var replacement: GitHubCredential {
        GitHubCredential(
            accessToken: "new-access",
            refreshToken: "new-refresh",
            expiresAt: now.addingTimeInterval(28800),
            refreshExpiresAt: now.addingTimeInterval(86400)
        )
    }

    @Test
    func existingPersonalTokenMigratesWithoutReauthorization() throws {
        let old = try VaultCredentialCodec.decode(Data("github_pat_existing".utf8))
        #expect(old.isLegacy)
        #expect(old.credential.accessToken == "github_pat_existing")
        #expect(old.credential.expiresAt == nil)
        let migrated = try VaultCredentialCodec.decode(VaultCredentialCodec.encode(old.credential))
        #expect(!migrated.isLegacy)
        #expect(migrated.credential == old.credential)
    }

    @Test(arguments: [
        Data("{\"accessToken\":7}".utf8),
        Data("{\"accessToken\":\"abc\",\"expiresAt\":1000}".utf8),
        Data("{broken-json".utf8),
        Data("token\r\nInjected: header".utf8),
        Data([0xFF])
    ])
    func corruptCredentialsAreNotTreatedAsPersonalTokens(_ data: Data) {
        #expect(throws: VaultError.self) { try VaultCredentialCodec.decode(data) }
    }

    @Test
    func personalAndUnexpiredTokensDoNotRequireNetworkRefresh() async throws {
        let credentials = [
            GitHubCredential(accessToken: "personal-token"),
            GitHubCredential(
                accessToken: "current-access",
                refreshToken: "current-refresh",
                expiresAt: now.addingTimeInterval(61)
            )
        ]
        for credential in credentials {
            let resolved = try await VaultCredentialRefresh.resolve(credential, using: { _ in
                throw CredentialTestError.unexpectedRefresh
            }, persist: { _ in throw CredentialTestError.unexpectedWrite }, now: now)
            #expect(resolved == credential)
        }
    }

    @Test
    func refreshWindowIncludesBoundaryAndPersistsBothRotatedTokens() async throws {
        let expiring = GitHubCredential(
            accessToken: "old-access",
            refreshToken: "old-refresh",
            expiresAt: now.addingTimeInterval(60)
        )
        let replacement = replacement
        var stored = expiring
        let result = try await VaultCredentialRefresh.resolve(expiring, using: { _ in replacement }, persist: {
            stored = try VaultCredentialCodec.decode(VaultCredentialCodec.encode($0)).credential
        }, now: now)
        #expect(stored == replacement)
        #expect(result == replacement)
    }

    @Test
    func cancellationDuringRefreshStillPersistsRotatedCredentials() async throws {
        let gate = CredentialRefreshGate()
        var stored = expired
        let task = Task {
            try await VaultCredentialRefresh.resolve(expired, using: { _ in await gate.refresh() }, persist: {
                stored = $0
            }, now: now)
        }
        await gate.waitUntilStarted()
        task.cancel()
        await gate.complete(with: replacement)
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(stored == replacement)
    }

    @Test
    func cancellationBeforeRefreshDoesNotRotateOrPersist() async {
        let task = Task {
            try await VaultCredentialRefresh.resolve(expired, using: { _ in
                throw CredentialTestError.unexpectedRefresh
            }, persist: { _ in throw CredentialTestError.unexpectedWrite }, now: now)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func failedPersistenceDoesNotReturnUnstoredCredentials() async {
        let replacement = replacement
        await #expect(throws: CredentialTestError.writeDenied) {
            try await VaultCredentialRefresh.resolve(expired, using: { _ in replacement }, persist: { _ in
                throw CredentialTestError.writeDenied
            }, now: now)
        }
    }

    @Test
    func rejectedRefreshDoesNotOverwriteSavedCredentials() async {
        await #expect(throws: GitHubDeviceOAuthError.authorizationFailed) {
            try await VaultCredentialRefresh.resolve(expired, using: { _ in
                throw GitHubDeviceOAuthError.authorizationFailed
            }, persist: { _ in throw CredentialTestError.unexpectedWrite }, now: now)
        }
    }
}

private enum CredentialTestError: Error, Equatable {
    case unexpectedRefresh, unexpectedWrite, writeDenied
}

private actor CredentialRefreshGate {
    private var pending: CheckedContinuation<GitHubCredential, Never>?
    private var observer: CheckedContinuation<Void, Never>?
    private var started = false

    func refresh() async -> GitHubCredential {
        await withCheckedContinuation {
            pending = $0
            started = true
            observer?.resume()
            observer = nil
        }
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { observer = $0 }
    }

    func complete(with credential: GitHubCredential) {
        pending?.resume(returning: credential)
        pending = nil
    }
}
