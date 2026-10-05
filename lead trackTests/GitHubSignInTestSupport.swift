import Foundation
import Testing
@testable import lead_track

actor GitHubSignInTestAuthorizer: GitHubDeviceAuthorizing {
    private var starts: [CheckedContinuation<GitHubDeviceAuthorization, any Error>?] = []
    private var polls: [CheckedContinuation<GitHubCredential, any Error>?] = []
    private var startWaiter: (Int, CheckedContinuation<Void, Never>)?
    private var pollWaiter: (Int, CheckedContinuation<Void, Never>)?

    var startCount: Int {
        starts.count
    }

    var pollCount: Int {
        polls.count
    }

    /// Deliberately ignore task cancellation to exercise late-response rejection in the consumer.
    func start() async throws -> GitHubDeviceAuthorization {
        try await withCheckedThrowingContinuation { continuation in
            starts.append(continuation)
            if let (count, waiter) = startWaiter, starts.count >= count {
                startWaiter = nil
                waiter.resume()
            }
        }
    }

    func poll(_: GitHubDeviceAuthorization) async throws -> GitHubCredential {
        try await withCheckedThrowingContinuation { continuation in
            polls.append(continuation)
            if let (count, waiter) = pollWaiter, polls.count >= count {
                pollWaiter = nil
                waiter.resume()
            }
        }
    }

    func waitForStart(_ count: Int) async {
        if starts.count >= count { return }
        await withCheckedContinuation { startWaiter = (count, $0) }
    }

    func waitForPoll(_ count: Int) async {
        if polls.count >= count { return }
        await withCheckedContinuation { pollWaiter = (count, $0) }
    }

    func finishStart(_ index: Int, with result: Result<GitHubDeviceAuthorization, any Error>) throws {
        let continuation = try #require(starts[index])
        starts[index] = nil
        continuation.resume(with: result)
    }

    func finishPoll(_ index: Int, with result: Result<GitHubCredential, any Error>) throws {
        let continuation = try #require(polls[index])
        polls[index] = nil
        continuation.resume(with: result)
    }
}

@MainActor
final class GitHubSignInTestHarness {
    let authorizer = GitHubSignInTestAuthorizer()
    var now = Date(timeIntervalSince1970: 1000)
    lazy var model = GitHubSignInModel(authorizer: authorizer, now: { [unowned self] in self.now })
    var installedDestinations: [VaultConfiguration] = []
    var installationSucceeds = true

    var destination: VaultConfiguration {
        VaultConfiguration(owner: "owner", repository: "vault", branch: "main", folder: "LeadStone")
    }

    var credential: GitHubCredential {
        GitHubCredential(
            accessToken: "test-access",
            refreshToken: "test-refresh",
            expiresAt: now.addingTimeInterval(28800)
        )
    }

    func authorization(code: String = "ABCD-EFGH") -> GitHubDeviceAuthorization {
        GitHubDeviceAuthorization(
            userCode: code,
            verificationURL: URL(string: "https://github.com/login/device")!,
            deviceCode: "private-device-code",
            expiresAt: now.addingTimeInterval(900),
            interval: 5
        )
    }

    func authorize() throws -> Task<Void, Never> {
        let identity = try #require(model.prepare(configuration: destination))
        return try #require(model.authorize(consentFor: identity, connect: install))
    }

    func install(destination: VaultConfiguration, credential _: GitHubCredential) -> Bool {
        installedDestinations.append(destination)
        return installationSucceeds
    }

    func reachApproval() async throws -> Task<Void, Never> {
        let task = try authorize()
        await authorizer.waitForStart(1)
        try await authorizer.finishStart(0, with: .success(authorization()))
        await authorizer.waitForPoll(1)
        return task
    }
}
