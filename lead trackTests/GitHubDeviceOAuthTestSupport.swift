import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

final nonisolated class GitHubDeviceOAuthClock: @unchecked Sendable {
    private let lock = NSLock()
    private var date = Date(timeIntervalSince1970: 1000)
    private var intervals: [TimeInterval] = []

    var now: Date {
        lock.withLock { date }
    }

    var sleeps: [TimeInterval] {
        lock.withLock { intervals }
    }

    func advance(_ seconds: TimeInterval) {
        lock.withLock {
            intervals.append(seconds)
            date.addTimeInterval(seconds)
        }
    }

    func client(_ replies: [GitHubDeviceOAuthStub.Reply]) -> GitHubDeviceOAuth {
        GitHubDeviceOAuth(
            clientID: "public-client", session: GitHubDeviceOAuthStub.session(replies),
            now: { self.now }, sleep: { self.advance($0) }
        )
    }

    func authorization(duration: TimeInterval = 900) -> GitHubDeviceAuthorization {
        GitHubDeviceAuthorization(
            userCode: "ABCD-EFGH", verificationURL: URL(string: "https://github.com/login/device")!,
            deviceCode: "private-device-code", expiresAt: now.addingTimeInterval(duration), interval: 5
        )
    }
}

final nonisolated class GitHubDeviceOAuthStub: URLProtocol {
    struct Reply {
        var body: Data
        var status = 200
        var destination: URL?
        var headers: [String: String] = [:]
        var beforeFinish: (() -> Void)?
        var error: URLError?

        init(_ object: [String: Any]) throws {
            body = try JSONSerialization.data(withJSONObject: object)
        }

        init(data: Data) {
            body = data
        }

        init(error: URLError.Code) {
            body = Data()
            self.error = URLError(error, userInfo: [NSLocalizedDescriptionKey: "private-device-code"])
        }
    }

    private static let lock = NSLock()
    private static var replies: [Reply] = []
    private static var requests: [URLRequest] = []
    private static let transport: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GitHubDeviceOAuthStub.self]
        return GitHubDeviceOAuthHTTP.session(configuration: configuration)
    }()

    static var recordedRequests: [URLRequest] {
        lock.withLock { requests }
    }

    static func session(_ replies: [Reply]) -> URLSession {
        lock.withLock { self.replies = replies; requests = [] }
        return transport
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func stopLoading() {}

    override func startLoading() {
        let reply = Self.lock.withLock { () -> Reply? in
            Self.requests.append(request)
            return Self.replies.isEmpty ? nil : Self.replies.removeFirst()
        }
        if let error = reply?.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        guard let reply, let url = reply.destination ?? request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: reply.status,
                  httpVersion: nil,
                  headerFields: reply.headers
              )
        else { client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse)); return }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.body)
        reply.beforeFinish?()
        client?.urlProtocolDidFinishLoading(self)
    }

    static var success: [String: Any] {
        ["access_token": "private-access-token", "token_type": "bearer", "scope": "repo"]
    }

    static var authorization: [String: Any] {
        [
            "user_code": "ABCD-EFGH",
            "device_code": "private-device-code",
            "verification_uri": "https://github.com/login/device",
            "expires_in": 900,
            "interval": 5
        ]
    }
}

final nonisolated class GitHubDeviceOAuthCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelAction: (@Sendable () -> Void)?
    private var requested = false

    var isInstalled: Bool {
        lock.withLock { cancelAction != nil }
    }

    func install(_ action: @escaping @Sendable () -> Void) {
        let shouldCancel = lock.withLock { cancelAction = action; return requested }
        if shouldCancel { action() }
    }

    func cancel() {
        let action = lock.withLock { requested = true; return cancelAction }
        action?()
    }
}
