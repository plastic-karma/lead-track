import Foundation
import Observation

@MainActor
@Observable
final class GitHubSignInModel {
    enum State: Equatable {
        case idle
        case awaitingConsent
        case starting
        case awaitingApproval
        case succeeded
        case failed(String)
    }

    struct Code: Equatable {
        let userCode: String
        let verificationURL: URL
        let expiresAt: Date
    }

    private(set) var state: State = .idle
    private(set) var code: Code?
    private(set) var destination: VaultConfiguration?
    private(set) var attemptID: UUID?
    @ObservationIgnored private let authorizer: (any GitHubDeviceAuthorizing)?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var operation: Task<Void, Never>?

    var isAvailable: Bool {
        authorizer != nil
    }

    var isInFlight: Bool {
        attemptID != nil
    }

    var errorMessage: String? {
        if case let .failed(message) = state { return message }
        return nil
    }

    init(authorizer: (any GitHubDeviceAuthorizing)?, now: @escaping () -> Date = Date.init) {
        self.authorizer = authorizer
        self.now = now
    }

    /// Freeze a validated destination before asking for permission to synchronize sensitive records.
    func prepare(configuration: VaultConfiguration) -> UUID? {
        guard !isInFlight else { return nil }
        guard isAvailable else {
            state = .failed(GitHubDeviceOAuthError.missingConfiguration.localizedDescription)
            return nil
        }
        do {
            destination = try configuration.validated()
            let identity = UUID()
            attemptID = identity
            state = .awaitingConsent
            return identity
        } catch {
            state = .failed(error.localizedDescription)
            return nil
        }
    }

    /// Consent applies only to this attempt. Credentials are consumed synchronously, never published as state.
    @discardableResult
    func authorize(
        consentFor identity: UUID,
        connect: @escaping @MainActor (VaultConfiguration, GitHubCredential) -> Bool
    ) -> Task<Void, Never>? {
        guard attemptID == identity, state == .awaitingConsent,
              let destination, let authorizer else { return nil }
        state = .starting
        let task = Task<Void, Never> { [weak self] in
            await self?.run(authorizer, identity: identity, destination: destination, connect: connect)
        }
        operation = task
        return task
    }

    /// Navigation and explicit cancellation invalidate the attempt before canceling its network operation.
    func cancel() {
        attemptID = nil
        operation?.cancel()
        operation = nil
        code = nil
        destination = nil
        state = .idle
    }

    private func run(
        _ authorizer: any GitHubDeviceAuthorizing, identity: UUID, destination: VaultConfiguration,
        connect: @MainActor (VaultConfiguration, GitHubCredential) -> Bool
    ) async {
        do {
            let authorization = try await authorizer.start()
            try checkCurrent(identity, expiresAt: authorization.expiresAt)
            code = Code(
                userCode: authorization.userCode,
                verificationURL: authorization.verificationURL,
                expiresAt: authorization.expiresAt
            )
            state = .awaitingApproval
            let credential = try await authorizer.poll(authorization)
            try checkCurrent(identity, expiresAt: authorization.expiresAt)
            let connected = connect(destination, credential)
            finish(identity, state: connected ? .succeeded : .failed(
                "GitHub sign-in succeeded, but sync could not be enabled. Review the sync error and try again."
            ))
        } catch {
            finish(identity, state: failureState(error))
        }
    }

    private func checkCurrent(_ identity: UUID, expiresAt: Date) throws {
        try Task.checkCancellation()
        guard attemptID == identity else { throw CancellationError() }
        guard now() < expiresAt else { throw GitHubDeviceOAuthError.expired }
    }

    private func failureState(_ error: any Error) -> State {
        if error is CancellationError || Task.isCancelled { return .idle }
        if let error = error as? GitHubDeviceOAuthError { return .failed(error.localizedDescription) }
        return .failed("GitHub sign-in could not be completed. Please try again.")
    }

    private func finish(_ identity: UUID, state: State) {
        guard attemptID == identity else { return }
        attemptID = nil
        operation = nil
        code = nil
        destination = nil
        self.state = state
    }
}
