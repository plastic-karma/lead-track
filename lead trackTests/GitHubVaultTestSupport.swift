import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

final class GitHubVaultStub: URLProtocol {
    struct Reply {
        let method: String
        let suffix: String
        let status: Int
        let payload: (URLRequest) throws -> Data

        init(_ suffix: String, _ object: Any, method: String = "GET", status: Int = 200) throws {
            self.method = method
            self.suffix = suffix
            self.status = status
            let data = try JSONSerialization.data(withJSONObject: object)
            payload = { _ in data }
        }

        init(_ suffix: String, respond: @escaping (URLRequest) throws -> Data) {
            method = "POST"
            self.suffix = suffix
            status = 200
            payload = respond
        }
    }

    private static let lock = NSLock()
    private static var replies: [Reply] = []
    private static var requests: [URLRequest] = []

    static func session(replies: [Reply]) -> URLSession {
        lock.withLock {
            self.replies = replies
            requests = []
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [GitHubVaultStub.self]
        return URLSession(configuration: configuration)
    }

    static var recordedRequests: [URLRequest] {
        lock.withLock { requests }
    }

    static var remainingReplies: Int {
        lock.withLock { replies.count }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let reply = Self.lock.withLock { () -> Reply? in
            Self.requests.append(request)
            return Self.replies.isEmpty ? nil : Self.replies.removeFirst()
        }
        guard let reply, let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        #expect(request.httpMethod == reply.method)
        #expect(url.path.hasSuffix(reply.suffix))
        #expect(url.scheme == "https" && url.host == "api.github.com")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-token")
        guard let data = try? reply.payload(request),
              let response = HTTPURLResponse(url: url, statusCode: reply.status, httpVersion: nil, headerFields: nil)
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

enum GitHubVaultFixture {
    static let head = String(repeating: "a", count: 40)
    static let root = String(repeating: "b", count: 40)
    static let notes = String(repeating: "c", count: 40)
    static let vault = String(repeating: "d", count: 40)
    static let blob = String(repeating: "e", count: 40)
    static let other = String(repeating: "f", count: 40)
    static let configuration = VaultConfiguration(
        owner: "owner",
        repository: "repo",
        branch: "feature/vault",
        folder: "Notes/My Vault"
    )

    static func entry(_ path: String, sha: String = blob, mode: String = "100644", size: Int = 5) -> [String: Any] {
        ["path": path, "sha": sha, "mode": mode, "type": mode == "040000" ? "tree" : "blob", "size": size]
    }

    static func tree(_ sha: String, entries: [[String: Any]], truncated: Bool = false) -> [String: Any] {
        ["sha": sha, "tree": entries, "truncated": truncated]
    }

    static func reference(_ sha: String = head) -> [String: Any] {
        ["ref": "refs/heads/feature/vault", "object": ["type": "commit", "sha": sha]]
    }

    static func headReplies(_ sha: String = head) throws -> [GitHubVaultStub.Reply] {
        try [
            .init("/ref/heads/feature/vault", reference(sha)),
            .init("/commits/\(sha)", ["sha": sha, "tree": ["sha": root]])
        ]
    }

    static func treeReplies(_ entries: [[String: Any]], truncated: Bool = false) throws -> [GitHubVaultStub.Reply] {
        try [
            .init("/trees/\(root)", tree(root, entries: [
                entry("Notes", sha: notes, mode: "040000"), entry("unrelated.bin", size: Int.max)
            ])),
            .init("/trees/\(notes)", tree(notes, entries: [entry("My Vault", sha: vault, mode: "040000")])),
            .init("/trees/\(vault)", tree(vault, entries: entries, truncated: truncated))
        ]
    }

    static func blobReply(_ sha: String = blob, data: Data = Data("hello".utf8)) throws -> GitHubVaultStub.Reply {
        try .init(
            "/blobs/\(sha)",
            ["sha": sha, "encoding": "base64", "size": data.count, "content": data.base64EncodedString()]
        )
    }

    static func commitReply(_ oid: String) throws -> GitHubVaultStub.Reply {
        try .init("/graphql", ["data": ["createCommitOnBranch": ["commit": ["oid": oid]]]], method: "POST")
    }

    static func mutationInput(_ request: URLRequest?) throws -> [String: Any] {
        let request = try #require(request)
        let data = try #require(request.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let query = try #require(body["query"] as? String)
        #expect(query.contains("createCommitOnBranch(input: $input)"))
        #expect(query.contains("CreateCommitOnBranchInput!"))
        let variables = try #require(body["variables"] as? [String: Any])
        return try #require(variables["input"] as? [String: Any])
    }

    static func client(_ session: URLSession) -> GitHubVaultClient {
        GitHubVaultClient(configuration: configuration, token: "test-token", session: session)
    }
}

/// Models a head move immediately before the server evaluates the conditional mutation.
final class GitHubVaultConditionalBranch: @unchecked Sendable {
    private let lock = NSLock()
    private var currentHead: String
    private var publications = 0

    init(head: String) {
        currentHead = head
    }

    var head: String {
        lock.withLock { currentHead }
    }

    var publishedCount: Int {
        lock.withLock { publications }
    }

    func reply(movingTo concurrentHead: String) -> GitHubVaultStub.Reply {
        GitHubVaultStub.Reply("/graphql") { request in
            let input = try GitHubVaultFixture.mutationInput(request)
            return try self.lock.withLock {
                self.currentHead = concurrentHead
                guard input["expectedHeadOid"] as? String == self.currentHead else {
                    return try JSONSerialization.data(withJSONObject: [
                        "data": ["createCommitOnBranch": NSNull()],
                        "errors": [["type": "STALE_DATA", "message": "private server body test-token"]]
                    ])
                }
                self.publications += 1
                self.currentHead = String(repeating: "3", count: 40)
                return try JSONSerialization.data(withJSONObject: [
                    "data": ["createCommitOnBranch": ["commit": ["oid": self.currentHead]]]
                ])
            }
        }
    }
}
