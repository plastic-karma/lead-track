import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

@Suite(.serialized)
struct GitHubDeviceOAuthTests {
    @Test
    func signInAcceptsExpiringCredentialAndRefreshDenialIsSanitized() async throws {
        let clock = GitHubDeviceOAuthClock()
        var object = GitHubDeviceOAuthStub.success
        object["refresh_token"] = "refresh-token"
        object["expires_in"] = 28800
        object["refresh_token_expires_in"] = 15_897_600
        let client = try clock.client([
            .init(object), .init(["error": "bad_refresh_token", "error_description": "private-refresh-token"])
        ])
        let result = try await client.poll(clock.authorization())
        #expect(result.expiresAt == clock.now.addingTimeInterval(28800))
        #expect(result.refreshToken == "refresh-token")
        await #expect(throws: GitHubDeviceOAuthError.authorizationFailed) {
            try await client.refresh(result)
        }
    }

    @Test
    func missingConfigurationDoesNotSendRequest() async throws {
        for clientID in ["", " ", "$(GITHUB_CLIENT_ID)", "${GITHUB_CLIENT_ID}"] {
            let session = GitHubDeviceOAuthStub.session([])
            let client = GitHubDeviceOAuth(clientID: clientID, session: session)
            await #expect(throws: GitHubDeviceOAuthError.missingConfiguration) { try await client.start() }
            #expect(GitHubDeviceOAuthStub.recordedRequests.isEmpty)
        }
    }

    @Test
    func refreshRotatesCredentialsWithConservativeExpiry() async throws {
        let clock = GitHubDeviceOAuthClock()
        let startedAt = clock.now
        var object = GitHubDeviceOAuthStub.success
        object["refresh_token"] = "new-refresh-token"
        object["expires_in"] = 28800
        object["refresh_token_expires_in"] = 15_897_600
        var reply = try GitHubDeviceOAuthStub.Reply(object)
        reply.beforeFinish = { clock.advance(20) }
        let client = clock.client([reply])
        let result = try await client.refresh(GitHubCredential(accessToken: "old-token", refreshToken: "old-refresh"))
        #expect(result.accessToken == "private-access-token")
        #expect(result.refreshToken == "new-refresh-token")
        #expect(result.expiresAt == startedAt.addingTimeInterval(28800))
        #expect(result.refreshExpiresAt == startedAt.addingTimeInterval(15_897_600))
        #expect(GitHubDeviceOAuthStub.recordedRequests.count == 1)
    }

    @Test
    func refreshRejectsMissingRotationAndInvalidExpiry() async throws {
        var missingRotation = GitHubDeviceOAuthStub.success
        missingRotation["expires_in"] = 28800
        var invalidExpiry = GitHubDeviceOAuthStub.success
        invalidExpiry["refresh_token"] = "replacement"
        invalidExpiry["expires_in"] = -1
        var invalidRefreshExpiry = GitHubDeviceOAuthStub.success
        invalidRefreshExpiry["refresh_token"] = "replacement"
        invalidRefreshExpiry["expires_in"] = 28800
        invalidRefreshExpiry["refresh_token_expires_in"] = 0
        for object in [missingRotation, invalidExpiry, invalidRefreshExpiry] {
            let client = try GitHubDeviceOAuthClock().client([.init(object)])
            await #expect(throws: GitHubDeviceOAuthError.invalidResponse) {
                try await client.refresh(GitHubCredential(accessToken: "old", refreshToken: "old-refresh"))
            }
        }
    }

    @Test
    func expiredRefreshAndPATCannotBeRefreshed() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = clock.client([])
        await #expect(throws: GitHubDeviceOAuthError.expired) {
            try await client.refresh(GitHubCredential(
                accessToken: "old", refreshToken: "old-refresh", refreshExpiresAt: clock.now
            ))
        }
        await #expect(throws: GitHubDeviceOAuthError.authorizationFailed) {
            try await client.refresh(GitHubCredential(accessToken: "manual-pat"))
        }
        #expect(GitHubDeviceOAuthStub.recordedRequests.isEmpty)
    }

    @Test
    func startsAndSucceedsAfterPending() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([
            .init(GitHubDeviceOAuthStub.authorization), .init(["error": "authorization_pending"]),
            .init(GitHubDeviceOAuthStub.success)
        ])
        let authorization = try await client.start()
        #expect(authorization.userCode == "ABCD-EFGH")
        #expect(authorization.expiresAt == clock.now.addingTimeInterval(900))
        #expect(try await client.poll(authorization).accessToken == "private-access-token")
        #expect(clock.sleeps == [5, 5])
        let requests = GitHubDeviceOAuthStub.recordedRequests
        #expect(requests.map(\.url?.absoluteString) == [
            "https://github.com/login/device/code", "https://github.com/login/oauth/access_token",
            "https://github.com/login/oauth/access_token"
        ])
        for request in requests {
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            #expect(!request.httpShouldHandleCookies)
        }
    }

    @Test
    func slowDownIsCumulativeAndHonorsServerInterval() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = try clock.client([
            .init(["error": "slow_down"]), .init(["error": "slow_down", "interval": 20]),
            .init(["error": "authorization_pending"]), .init(GitHubDeviceOAuthStub.success)
        ])
        _ = try await client.poll(clock.authorization())
        #expect(clock.sleeps == [5, 10, 20, 20])
    }

    @Test
    func expiresWithoutPollingEarly() async throws {
        let clock = GitHubDeviceOAuthClock()
        let client = clock.client([])
        await #expect(throws: GitHubDeviceOAuthError.expired) {
            try await client.poll(clock.authorization(duration: 3))
        }
        #expect(clock.sleeps == [3])
        #expect(GitHubDeviceOAuthStub.recordedRequests.isEmpty)
    }

    @Test
    func terminalErrorsAreTypedAndSanitized() async throws {
        let failures: [(String, GitHubDeviceOAuthError)] = [
            ("expired_token", .expired), ("access_denied", .denied),
            ("device_flow_disabled", .deviceFlowDisabled), ("private-access-token", .authorizationFailed)
        ]
        for (wire, expected) in failures {
            let clock = GitHubDeviceOAuthClock()
            let client = try clock.client([.init(["error": wire, "error_description": "private-device-code"])])
            await #expect(throws: expected) { try await client.poll(clock.authorization()) }
            #expect(!expected.localizedDescription.contains("private-"))
        }
    }

    @Test
    func rejectsUnsafeVerificationURLsAndMalformedFields() async throws {
        let urls = [
            "http://github.com/login/device", "https://evil.test/login/device",
            "https://github.com:443/login/device", "https://user@github.com/login/device",
            "https://github.com/login/device?code=secret", "https://github.com/login/device#secret",
            "https://github.com/other"
        ]
        var invalid = urls.map { url in
            var object = GitHubDeviceOAuthStub.authorization
            object["verification_uri"] = url
            return object
        }
        for (key, value) in [("expires_in", 0), ("expires_in", 86401), ("interval", -1)] {
            var object = GitHubDeviceOAuthStub.authorization
            object[key] = value
            invalid.append(object)
        }
        var badCode = GitHubDeviceOAuthStub.authorization
        badCode["device_code"] = "secret\nheader"
        invalid.append(badCode)
        for object in invalid {
            let client = try GitHubDeviceOAuthClock().client([.init(object)])
            await #expect(throws: GitHubDeviceOAuthError.invalidResponse) { try await client.start() }
        }
    }

    @Test
    func rejectsInvalidTokensAndScopes() async throws {
        let invalid: [[String: Any]] = [
            ["access_token": "", "token_type": "bearer", "scope": "repo"],
            ["access_token": "secret\r\nHeader", "token_type": "bearer", "scope": "repo"],
            ["access_token": "secret", "token_type": "basic", "scope": "repo"],
            ["access_token": "secret", "token_type": "bearer", "scope": "public_repo"],
            ["access_token": "secret", "token_type": "bearer"],
            ["access_token": "secret", "error": "authorization_pending"],
            ["error": "slow_down", "interval": -5]
        ]
        for object in invalid {
            let clock = GitHubDeviceOAuthClock()
            let client = try clock.client([.init(object)])
            await #expect(throws: GitHubDeviceOAuthError.invalidResponse) {
                try await client.poll(clock.authorization())
            }
        }
    }

    @Test
    func rejectsRedirectsUnexpectedDestinationsAndOversizedBodies() async throws {
        var redirect = try GitHubDeviceOAuthStub.Reply(GitHubDeviceOAuthStub.authorization)
        redirect.status = 302
        redirect.headers = ["Location": "https://evil.test/collect"]
        var destination = try GitHubDeviceOAuthStub.Reply(GitHubDeviceOAuthStub.authorization)
        destination.destination = URL(string: "https://evil.test/collect")
        for reply in [redirect, destination] {
            let client = GitHubDeviceOAuthClock().client([reply])
            await #expect(throws: GitHubDeviceOAuthError.unsafeResponse) { try await client.start() }
            #expect(GitHubDeviceOAuthStub.recordedRequests.count == 1)
        }
        let oversized = GitHubDeviceOAuthStub.Reply(data: Data(repeating: 65, count: 65537))
        await #expect(throws: GitHubDeviceOAuthError.responseTooLarge) {
            try await GitHubDeviceOAuthClock().client([oversized]).start()
        }
        let malformed = GitHubDeviceOAuthStub.Reply(data: Data("private-device-code".utf8))
        await #expect(throws: GitHubDeviceOAuthError.invalidResponse) {
            try await GitHubDeviceOAuthClock().client([malformed]).start()
        }
    }

    @Test
    func cancellationDuringSleepPreventsPollEvenIfSleepReturns() async throws {
        let clock = GitHubDeviceOAuthClock()
        let cancellation = GitHubDeviceOAuthCancellation()
        let client = GitHubDeviceOAuth(
            clientID: "public-client", session: GitHubDeviceOAuthStub.session([]), now: { clock.now },
            sleep: { seconds in
                clock.advance(seconds)
                cancellation.cancel()
                while !Task.isCancelled {
                    await Task.yield()
                }
            }
        )
        let task = Task {
            while !cancellation.isInstalled {
                await Task.yield()
            }
            return try await client.poll(clock.authorization())
        }
        cancellation.install { task.cancel() }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(GitHubDeviceOAuthStub.recordedRequests.isEmpty)
    }

    @Test
    func cancellationRejectsLateSuccessfulResponse() async throws {
        let clock = GitHubDeviceOAuthClock()
        let cancellation = GitHubDeviceOAuthCancellation()
        var reply = try GitHubDeviceOAuthStub.Reply(GitHubDeviceOAuthStub.success)
        reply.beforeFinish = { cancellation.cancel() }
        let client = clock.client([reply])
        let task = Task {
            while !cancellation.isInstalled {
                await Task.yield()
            }
            return try await client.poll(clock.authorization())
        }
        cancellation.install { task.cancel() }
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func successArrivingAfterExpiryIsRejected() async throws {
        let clock = GitHubDeviceOAuthClock()
        var reply = try GitHubDeviceOAuthStub.Reply(GitHubDeviceOAuthStub.success)
        reply.beforeFinish = { clock.advance(900) }
        let client = clock.client([reply])
        await #expect(throws: GitHubDeviceOAuthError.expired) { try await client.poll(clock.authorization()) }
    }
}
