import Foundation
import Testing
@testable import lead_track

@MainActor
struct GitHubSignInModelTests {
    @Test
    func destinationIsValidatedAndFrozenUntilExplicitConsent() async throws {
        let harness = GitHubSignInTestHarness()
        var draft = harness.destination
        draft.owner = " owner "
        let identity = try #require(harness.model.prepare(configuration: draft))
        draft.repository = "different-vault"
        #expect(harness.model.state == .awaitingConsent)
        #expect(harness.model.destination == harness.destination)
        #expect(await harness.authorizer.startCount == 0)
        #expect(harness.installedDestinations.isEmpty)
        let task = try #require(harness.model.authorize(consentFor: identity, connect: harness.install))
        #expect(harness.model.state == .starting)
        #expect(harness.model.prepare(configuration: draft) == nil)
        #expect(harness.model.authorize(consentFor: identity, connect: harness.install) == nil)
        await harness.authorizer.waitForStart(1)
        try await harness.authorizer.finishStart(0, with: .success(harness.authorization()))
        await harness.authorizer.waitForPoll(1)
        #expect(harness.model.state == .awaitingApproval)
        #expect(harness.model.code != nil)
        try await harness.authorizer.finishPoll(0, with: .success(harness.credential))
        await task.value
        #expect(harness.installedDestinations == [harness.destination])
        #expect(harness.model.state == .succeeded)
        #expect(harness.model.code == nil && harness.model.destination == nil)
        #expect(!harness.model.isInFlight)
    }

    @Test
    func invalidDestinationCannotStartAuthorization() async {
        let harness = GitHubSignInTestHarness()
        var destination = harness.destination
        destination.folder = "../outside-vault"
        #expect(harness.model.prepare(configuration: destination) == nil)
        #expect(harness.model.errorMessage != nil)
        #expect(harness.model.destination == nil && !harness.model.isInFlight)
        #expect(await harness.authorizer.startCount == 0)
    }

    @Test
    func unavailableOAuthCannotPretendToSignIn() {
        let harness = GitHubSignInTestHarness()
        let model = GitHubSignInModel(authorizer: nil)
        #expect(!model.isAvailable)
        #expect(model.prepare(configuration: harness.destination) == nil)
        #expect(model.errorMessage != nil)
        #expect(!model.isInFlight)
    }

    @Test
    func dismissedConsentCannotAuthorizeAnotherAttempt() async throws {
        let harness = GitHubSignInTestHarness()
        let obsolete = try #require(harness.model.prepare(configuration: harness.destination))
        harness.model.cancel()
        let current = try #require(harness.model.prepare(configuration: harness.destination))
        #expect(harness.model.authorize(consentFor: obsolete, connect: harness.install) == nil)
        #expect(harness.model.attemptID == current)
        #expect(harness.model.state == .awaitingConsent)
        #expect(await harness.authorizer.startCount == 0)
        harness.model.cancel()
        #expect(harness.model.destination == nil)
    }

    @Test
    func canceledStartCannotDisplayCodeOrPollAfterLateResponse() async throws {
        let harness = GitHubSignInTestHarness()
        let task = try harness.authorize()
        await harness.authorizer.waitForStart(1)
        harness.model.cancel()
        #expect(task.isCancelled)
        try await harness.authorizer.finishStart(0, with: .success(harness.authorization()))
        await task.value
        #expect(harness.model.state == .idle)
        #expect(harness.model.code == nil && harness.model.destination == nil)
        #expect(await harness.authorizer.pollCount == 0)
        #expect(harness.installedDestinations.isEmpty)
    }

    @Test
    func navigationCancellationRejectsLateCredentialInstallation() async throws {
        let harness = GitHubSignInTestHarness()
        let task = try await harness.reachApproval()
        harness.model.cancel()
        #expect(harness.model.code == nil && !harness.model.isInFlight)
        try await harness.authorizer.finishPoll(0, with: .success(harness.credential))
        await task.value
        #expect(harness.model.state == .idle)
        #expect(harness.installedDestinations.isEmpty)
    }

    @Test(arguments: [GitHubDeviceOAuthError.denied, .expired])
    func terminalAuthorizationFailureNeverConnectsAndAllowsRetry(_ failure: GitHubDeviceOAuthError) async throws {
        let harness = GitHubSignInTestHarness()
        let task = try await harness.reachApproval()
        try await harness.authorizer.finishPoll(0, with: .failure(failure))
        await task.value
        #expect(harness.model.errorMessage != nil)
        #expect(harness.model.code == nil && harness.model.destination == nil)
        #expect(!harness.model.isInFlight)
        #expect(harness.installedDestinations.isEmpty)
        #expect(harness.model.prepare(configuration: harness.destination) != nil)
        #expect(harness.model.errorMessage == nil)
        harness.model.cancel()
    }

    @Test
    func credentialArrivingAfterDeviceExpiryNeverConnects() async throws {
        let harness = GitHubSignInTestHarness()
        let task = try await harness.reachApproval()
        harness.now = harness.now.addingTimeInterval(901)
        try await harness.authorizer.finishPoll(0, with: .success(harness.credential))
        await task.value
        #expect(harness.model.errorMessage != nil)
        #expect(harness.model.code == nil && !harness.model.isInFlight)
        #expect(harness.installedDestinations.isEmpty)
    }

    @Test
    func lateSuccessCannotConnectOrClearNewAttempt() async throws {
        let harness = GitHubSignInTestHarness()
        let old = try await harness.reachApproval()
        harness.model.cancel()
        let current = try harness.authorize()
        await harness.authorizer.waitForStart(2)
        try await harness.authorizer.finishStart(1, with: .success(harness.authorization(code: "IJKL-MNOP")))
        await harness.authorizer.waitForPoll(2)
        let identity = harness.model.attemptID
        try await harness.authorizer.finishPoll(0, with: .success(harness.credential))
        await old.value
        #expect(harness.model.attemptID == identity)
        #expect(harness.model.state == .awaitingApproval)
        #expect(harness.model.code?.userCode == "IJKL-MNOP")
        #expect(harness.installedDestinations.isEmpty)
        try await harness.authorizer.finishPoll(1, with: .success(harness.credential))
        await current.value
        #expect(harness.model.state == .succeeded)
        #expect(harness.installedDestinations.count == 1)
    }

    @Test
    func lateFailureCannotOverwriteNewAttempt() async throws {
        let harness = GitHubSignInTestHarness()
        let old = try await harness.reachApproval()
        harness.model.cancel()
        let current = try harness.authorize()
        await harness.authorizer.waitForStart(2)
        try await harness.authorizer.finishPoll(0, with: .failure(GitHubDeviceOAuthError.denied))
        await old.value
        #expect(harness.model.state == .starting)
        #expect(harness.model.isInFlight && harness.model.errorMessage == nil)
        harness.model.cancel()
        try await harness.authorizer.finishStart(1, with: .success(harness.authorization()))
        await current.value
        #expect(harness.installedDestinations.isEmpty)
    }

    @Test
    func connectionFailureDoesNotRetainApprovalOrReportSuccess() async throws {
        let harness = GitHubSignInTestHarness()
        harness.installationSucceeds = false
        let task = try await harness.reachApproval()
        try await harness.authorizer.finishPoll(0, with: .success(harness.credential))
        await task.value
        #expect(harness.model.errorMessage != nil)
        #expect(harness.model.code == nil && harness.model.destination == nil)
        #expect(!harness.model.isInFlight)
        #expect(harness.model.prepare(configuration: harness.destination) != nil)
        harness.model.cancel()
    }

    @Test
    func untrustedErrorDetailsNeverReachTheInterface() async throws {
        let harness = GitHubSignInTestHarness()
        let task = try await harness.reachApproval()
        let secret = "credential-and-device-code-must-not-be-displayed"
        let error = NSError(domain: "Untrusted", code: 1, userInfo: [NSLocalizedDescriptionKey: secret])
        try await harness.authorizer.finishPoll(0, with: .failure(error))
        await task.value
        let message = try #require(harness.model.errorMessage)
        #expect(!message.contains(secret))
        #expect(harness.installedDestinations.isEmpty)
    }
}
