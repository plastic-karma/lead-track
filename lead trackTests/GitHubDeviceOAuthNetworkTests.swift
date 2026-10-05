import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

extension GitHubDeviceOAuthTests {
    @Test
    @MainActor
    func approvedSignInSurvivesInterruptedPolling() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([
            .init(GitHubDeviceOAuthStub.authorization), .init(["error": "authorization_pending"]),
            .init(error: .timedOut), .init(error: .networkConnectionLost), .init(GitHubDeviceOAuthStub.success)
        ])
        let model = GitHubSignInModel(authorizer: client, now: { clock.now })
        let destination = VaultConfiguration(owner: "owner", repository: "vault", branch: "main", folder: "LeadStone")
        let identity = try #require(model.prepare(configuration: destination))
        var installed: GitHubCredential?
        let task = try #require(model.authorize(consentFor: identity) { _, credential in
            installed = credential
            return true
        })
        await task.value
        #expect(model.state == .succeeded)
        #expect(installed?.accessToken == "private-access-token")
        #expect(clock.sleeps == [5, 5, 10, 20])
    }

    @Test
    func networkBackoffPreservesServerSlowDown() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([
            .init(["error": "slow_down", "interval": 20]), .init(error: .timedOut),
            .init(["error": "authorization_pending"]), .init(GitHubDeviceOAuthStub.success)
        ])
        #expect(try await client.poll(clock.authorization()).accessToken == "private-access-token")
        #expect(clock.sleeps == [5, 20, 40, 40])
    }

    @Test
    func networkOutageCannotExtendAuthorizationExpiry() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([.init(error: .notConnectedToInternet), .init(GitHubDeviceOAuthStub.success)])
        await #expect(throws: GitHubDeviceOAuthError.expired) {
            try await client.poll(clock.authorization(duration: 9))
        }
        #expect(clock.sleeps == [5, 4])
        #expect(GitHubDeviceOAuthStub.recordedRequests.count == 1)
    }

    @Test
    func certificateFailureStopsPollingWithoutLeakingErrorMetadata() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([.init(error: .serverCertificateUntrusted), .init(GitHubDeviceOAuthStub.success)])
        do {
            _ = try await client.poll(clock.authorization())
            Issue.record("An untrusted certificate must stop authorization")
        } catch {
            let failure = try #require(error as? GitHubDeviceOAuthError)
            #expect(!failure.localizedDescription.contains("private-device-code"))
        }
        #expect(GitHubDeviceOAuthStub.recordedRequests.count == 1)
    }

    @Test
    func lostRefreshResponseDoesNotReplayCredentialRotation() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = clock.client([.init(error: .networkConnectionLost)])
        await #expect(throws: GitHubDeviceOAuthError.self) {
            try await client.refresh(GitHubCredential(accessToken: "old-token", refreshToken: "old-refresh"))
        }
        #expect(GitHubDeviceOAuthStub.recordedRequests.count == 1)
        #expect(clock.sleeps.isEmpty)
    }
}
