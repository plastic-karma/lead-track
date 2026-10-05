import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

nonisolated struct GitHubDeviceAuthorization: Equatable {
    let userCode: String
    let verificationURL: URL
    let deviceCode: String
    let expiresAt: Date
    let interval: TimeInterval
}

protocol GitHubDeviceAuthorizing: Sendable {
    nonisolated func start() async throws -> GitHubDeviceAuthorization
    nonisolated func poll(_ authorization: GitHubDeviceAuthorization) async throws -> GitHubCredential
}

nonisolated enum GitHubDeviceOAuthError: Error, LocalizedError, Equatable {
    case missingConfiguration, invalidResponse, unsafeResponse, responseTooLarge
    case expired, denied, deviceFlowDisabled, authorizationFailed
    case connectionFailed(URLError.Code)

    var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            "GitHub sign-in is not configured in this build. You can use a personal access token instead."
        case .invalidResponse: "GitHub returned invalid sign-in details. Please start sign-in again."
        case .unsafeResponse: "GitHub returned an unexpected sign-in destination. No credentials were forwarded."
        case .responseTooLarge: "GitHub returned an oversized sign-in response."
        case .expired: "GitHub authorization expired. Start sign-in again."
        case .denied: "GitHub authorization was declined. You can start sign-in again."
        case .deviceFlowDisabled: "Device Flow is disabled for this GitHub app. Use a personal access token instead."
        case .authorizationFailed: "GitHub could not authorize this sign-in. Please start again."
        case let .connectionFailed(code):
            "Could not contact GitHub (network error \(code.rawValue)). Check your connection and try again."
        }
    }

    var isRecoverableNetworkFailure: Bool {
        guard case let .connectionFailed(code) = self else { return false }
        switch code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet,
             .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}

/// Secretless Device Flow. The caller must store the returned token only in Keychain.
nonisolated struct GitHubDeviceOAuth: GitHubDeviceAuthorizing {
    private let clientID: String
    private let session: URLSession?
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    init(
        clientID: String,
        session: URLSession? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.clientID = clientID
        self.session = session
        self.now = now
        self.sleep = sleep
    }

    func start() async throws -> GitHubDeviceAuthorization {
        let startedAt = now()
        let wire = try await form("device/code", fields: ["client_id": clientID, "scope": "repo"])
        if let error = wire.error { throw failure(error) }
        guard let userCode = wire.userCode, Self.validCode(userCode),
              let deviceCode = wire.deviceCode, Self.validCode(deviceCode),
              wire.verificationURI == "https://github.com/login/device",
              let url = wire.verificationURI.flatMap(URL.init(string:)),
              let duration = wire.expiresIn, Self.validDuration(duration),
              Self.validDuration(wire.interval ?? 5)
        else { throw GitHubDeviceOAuthError.invalidResponse }
        try Task.checkCancellation()
        return GitHubDeviceAuthorization(
            userCode: userCode, verificationURL: url, deviceCode: deviceCode,
            expiresAt: startedAt.addingTimeInterval(duration), interval: wire.interval ?? 5
        )
    }

    func poll(_ authorization: GitHubDeviceAuthorization) async throws -> GitHubCredential {
        guard Self.validCode(authorization.deviceCode), Self.validDuration(authorization.interval),
              authorization.expiresAt.timeIntervalSince1970.isFinite,
              authorization.verificationURL.absoluteString == "https://github.com/login/device"
        else { throw GitHubDeviceOAuthError.invalidResponse }
        var interval = authorization.interval
        while true {
            try await wait(interval, until: authorization.expiresAt)
            let startedAt = now()
            let wire: GitHubDeviceOAuthWire
            do {
                wire = try await form("oauth/access_token", fields: [
                    "client_id": clientID, "device_code": authorization.deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code"
                ])
            } catch let error as GitHubDeviceOAuthError where error.isRecoverableNetworkFailure {
                // RFC 8628 §3.5: keep the device grant, but reduce polling after a timeout.
                // The next wait still enforces cancellation and the original authorization expiry.
                interval *= 2
                continue
            }
            try Task.checkCancellation()
            guard now() < authorization.expiresAt else { throw GitHubDeviceOAuthError.expired }
            if let error = wire.error {
                interval = try nextInterval(error, wire: wire, current: interval)
            } else {
                return try token(wire, startedAt: startedAt)
            }
        }
    }

    private func wait(_ interval: TimeInterval, until expiry: Date) async throws {
        try Task.checkCancellation()
        let remaining = expiry.timeIntervalSince(now())
        guard remaining > 0 else { throw GitHubDeviceOAuthError.expired }
        try await sleep(min(interval, remaining))
        try Task.checkCancellation()
        guard now() < expiry else { throw GitHubDeviceOAuthError.expired }
    }

    private func nextInterval(
        _ error: String,
        wire: GitHubDeviceOAuthWire,
        current: TimeInterval
    ) throws -> TimeInterval {
        guard wire.accessToken == nil else { throw GitHubDeviceOAuthError.invalidResponse }
        switch error {
        case "authorization_pending": return current
        case "slow_down":
            if let suggested = wire.interval, !Self.validDuration(suggested) {
                throw GitHubDeviceOAuthError.invalidResponse
            }
            return max(current + 5, wire.interval ?? 0)
        default: throw failure(error)
        }
    }

    private func token(_ wire: GitHubDeviceOAuthWire, startedAt: Date) throws -> GitHubCredential {
        guard let token = wire.accessToken, Self.validCode(token),
              wire.tokenType?.lowercased() == "bearer", let scope = wire.scope,
              scope.split(whereSeparator: { $0 == "," || $0 == " " }).contains("repo")
        else { throw GitHubDeviceOAuthError.invalidResponse }
        let expiry = try expiry(wire.expiresIn, since: startedAt)
        let refreshExpiry = try self.expiry(wire.refreshTokenExpiresIn, since: startedAt)
        if let refresh = wire.refreshToken, !Self.validCode(refresh) {
            throw GitHubDeviceOAuthError.invalidResponse
        }
        guard expiry == nil || wire.refreshToken != nil,
              refreshExpiry == nil || wire.refreshToken != nil,
              expiry.map({ $0 > now() }) ?? true
        else { throw GitHubDeviceOAuthError.invalidResponse }
        return GitHubCredential(
            accessToken: token,
            refreshToken: wire.refreshToken,
            expiresAt: expiry,
            refreshExpiresAt: refreshExpiry
        )
    }

    func refresh(_ credential: GitHubCredential) async throws -> GitHubCredential {
        try Task.checkCancellation()
        guard let refresh = credential.refreshToken, Self.validCode(refresh) else {
            throw GitHubDeviceOAuthError.authorizationFailed
        }
        let startedAt = now()
        if let expiry = credential.refreshExpiresAt, expiry <= startedAt {
            throw GitHubDeviceOAuthError.expired
        }
        let wire = try await form("oauth/access_token", fields: [
            "client_id": clientID, "grant_type": "refresh_token", "refresh_token": refresh
        ])
        if let error = wire.error { throw failure(error) }
        let replacement = try token(wire, startedAt: startedAt)
        guard replacement.refreshToken != nil, replacement.expiresAt != nil else {
            throw GitHubDeviceOAuthError.invalidResponse
        }
        try Task.checkCancellation()
        return replacement
    }

    private func expiry(_ seconds: Double?, since startedAt: Date) throws -> Date? {
        guard let seconds else { return nil }
        guard seconds.isFinite, seconds > 0, seconds <= 366 * 86400 else {
            throw GitHubDeviceOAuthError.invalidResponse
        }
        return startedAt.addingTimeInterval(seconds)
    }

    private func form(_ endpoint: String, fields: [String: String]) async throws -> GitHubDeviceOAuthWire {
        try Task.checkCancellation()
        guard Self.validCode(clientID), !clientID.contains("$("), !clientID.contains("${") else {
            throw GitHubDeviceOAuthError.missingConfiguration
        }
        let data = try await GitHubDeviceOAuthHTTP.send(endpoint, fields: fields, session: session)
        try Task.checkCancellation()
        do { return try JSONDecoder().decode(GitHubDeviceOAuthWire.self, from: data) }
        catch { throw GitHubDeviceOAuthError.invalidResponse }
    }

    private func failure(_ error: String) -> GitHubDeviceOAuthError {
        switch error {
        case "expired_token": .expired
        case "access_denied": .denied
        case "device_flow_disabled": .deviceFlowDisabled
        default: .authorizationFailed
        }
    }

    private static func validCode(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 4096 && value.unicodeScalars
            .allSatisfy { (33 ... 126).contains($0.value) }
    }

    private static func validDuration(_ value: TimeInterval) -> Bool {
        value.isFinite && value > 0 && value <= 86400
    }
}

private nonisolated struct GitHubDeviceOAuthWire: Decodable {
    let userCode: String?
    let verificationURI: String?
    let deviceCode: String?
    let expiresIn: Double?
    let interval: Double?
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?
    let refreshToken: String?
    let refreshTokenExpiresIn: Double?

    private enum CodingKeys: String, CodingKey {
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case deviceCode = "device_code"
        case expiresIn = "expires_in"
        case accessToken = "access_token"
        case tokenType = "token_type"
        case refreshToken = "refresh_token"
        case refreshTokenExpiresIn = "refresh_token_expires_in"
        case interval, scope, error
    }
}
