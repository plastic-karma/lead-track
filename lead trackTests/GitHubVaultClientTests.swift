import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

@Suite(.serialized)
struct GitHubVaultClientTests {
    private typealias Fixture = GitHubVaultFixture

    @Test
    func fetchesSelectedFolderAndCachesIdenticalBlobsAcrossPathsAndFetches() async throws {
        let image = Data([0, 255, 1, 128])
        let imageSHA = String(repeating: "7", count: 40)
        let entries = [
            Fixture.entry("one.md"), Fixture.entry("two.md"),
            Fixture.entry("Overview.base", sha: Fixture.other, size: 2),
            Fixture.entry("Attachments", mode: "040000"),
            Fixture.entry("Attachments/image.png", sha: imageSHA, size: image.count),
            Fixture.entry("unrelated.bin", size: Int.max)
        ]
        let replies = try Fixture.headReplies() + Fixture.treeReplies(entries) + [
            Fixture.blobReply(), Fixture.blobReply(imageSHA, data: image)
        ] + Fixture.headReplies()
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let client = Fixture.client(session)
        let cached = ["old-name.base": VaultRemoteFile(sha: Fixture.other, data: Data("{}".utf8))]
        let first = try await client.fetch(cached: cached)
        let second = try await client.fetch(cached: [:])
        #expect(first.files == second.files)
        #expect(Set(first.files.keys) == ["one.md", "two.md", "Overview.base", "Attachments/image.png"])
        #expect(first.headSHA == Fixture.head && first.treeSHA == Fixture.root)
        #expect(first.files["Attachments/image.png"]?.data == image)
        #expect(GitHubVaultStub.recordedRequests.filter { $0.url?.path.contains("/blobs/") == true }.count == 2)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test
    func atomicallyCommitsUpdatesAndDeletesWithoutTouchingUnrelatedFiles() async throws {
        let newCommit = String(repeating: "3", count: 40)
        let replies = try Fixture.headReplies() + Fixture.treeReplies([
            Fixture.entry("one.md"), Fixture.entry("delete.md"), Fixture.entry("unrelated.bin", size: Int.max)
        ]) + [Fixture.commitReply(newCommit)]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [
            "one.md": VaultRemoteFile(sha: Fixture.blob, data: Data("hello".utf8)),
            "delete.md": VaultRemoteFile(sha: Fixture.blob, data: Data("hello".utf8))
        ])
        let image = Data([0, 255, 128])
        let changes = [
            VaultFileChange(path: "one.md", data: Data("new".utf8)),
            VaultFileChange(path: "Attachments/photo.png", data: image),
            VaultFileChange(path: "delete.md", data: nil)
        ]
        let result = try await Fixture.client(session).commit(changes: changes, onto: snapshot)
        #expect(result == newCommit)
        let requests = GitHubVaultStub.recordedRequests
        #expect(requests.filter { $0.httpMethod != "GET" }.count == 1)
        #expect(requests.last?.url?.absoluteString == "https://api.github.com/graphql")
        let input = try Fixture.mutationInput(requests.last)
        #expect(input["expectedHeadOid"] as? String == Fixture.head)
        #expect(input["branch"] as? [String: String] == [
            "repositoryNameWithOwner": "owner/repo", "branchName": "feature/vault"
        ])
        try expectFileChanges(input, image: image)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test
    func staleHeadIsConflictBeforeAnyWrites() async throws {
        let session = try GitHubVaultStub.session(replies: Fixture.headReplies(Fixture.other))
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [:])
        do {
            _ = try await Fixture.client(session).commit(
                changes: [VaultFileChange(path: "new.md", data: Data())],
                onto: snapshot
            )
            Issue.record("Expected a stale-head conflict")
        } catch VaultError.conflict {}
        #expect(GitHubVaultStub.recordedRequests.allSatisfy { $0.httpMethod == "GET" })
    }

    @Test(arguments: [String(repeating: "1", count: 40), String(repeating: "2", count: 40)])
    func forwardPushOrBackwardResetDuringPublicationCannotPublish(_ concurrentHead: String) async throws {
        // Both a descendant push and an ancestor force reset must compare unequal to the fetched head.
        let branch = GitHubVaultConditionalBranch(head: Fixture.head)
        let replies = try Fixture.headReplies() + Fixture.treeReplies([]) + Fixture.headReplies() + [
            branch.reply(movingTo: concurrentHead)
        ]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let client = Fixture.client(session)
        let snapshot = try await client.fetch(cached: [:])
        do {
            _ = try await client.commit(changes: [VaultFileChange(path: "new.md", data: Data())], onto: snapshot)
            Issue.record("Expected a conditional-publication conflict")
        } catch let VaultError.conflict(message) {
            #expect(!message.contains("test-token") && !message.contains("private server body"))
        }
        #expect(branch.head == concurrentHead)
        #expect(branch.publishedCount == 0)
        #expect(GitHubVaultStub.recordedRequests.filter { $0.httpMethod != "GET" }.count == 1)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: ["FORBIDDEN", "RATE_LIMITED", "UNPROCESSABLE", "UNKNOWN"])
    func graphQLErrorsAtHTTP200AreSanitizedAndNeverAcknowledged(_ type: String) async throws {
        let reply: [String: Any] = [
            "data": ["createCommitOnBranch": ["commit": ["oid": Fixture.other]]],
            "errors": [["type": type, "message": "private note content test-token"]]
        ]
        let replies = try Fixture.headReplies() + Fixture.treeReplies([]) + [
            .init("/graphql", reply, method: "POST")
        ]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [:])
        do {
            _ = try await Fixture.client(session).commit(changes: [
                VaultFileChange(path: "new.md", data: Data("private note content".utf8))
            ], onto: snapshot)
            Issue.record("Expected a sanitized GraphQL failure")
        } catch let VaultError.remote(message) {
            #expect(!message.contains("test-token") && !message.contains("private note content"))
            #expect(message.contains("Contents read/write"))
        }
        #expect(GitHubVaultStub.recordedRequests.filter { $0.httpMethod != "GET" }.count == 1)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: ["missing", "invalidOID", "malformed"])
    func unacknowledgedOrMalformedPublicationIsNeverSuccess(_ kind: String) async throws {
        let payloads: [String: [String: Any]] = [
            "missing": ["data": ["createCommitOnBranch": NSNull()]],
            "invalidOID": ["data": ["createCommitOnBranch": ["commit": ["oid": "test-token"]]]],
            "malformed": ["data": "private note content test-token"]
        ]
        let reply = try #require(payloads[kind])
        let replies = try Fixture.headReplies() + Fixture.treeReplies([]) + [
            .init("/graphql", reply, method: "POST")
        ]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [:])
        do {
            _ = try await Fixture.client(session).commit(
                changes: [VaultFileChange(path: "new.md", data: Data())],
                onto: snapshot
            )
            Issue.record("Expected a missing or malformed commit acknowledgement failure")
        } catch let VaultError.remote(message) {
            #expect(!message.contains("test-token") && !message.contains("private note content"))
        }
        #expect(GitHubVaultStub.recordedRequests.filter { $0.httpMethod != "GET" }.count == 1)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: [401, 403, 413, 422, 429])
    func publicationHTTPFailuresAreSanitizedWithoutRetry(_ status: Int) async throws {
        let replies = try Fixture.headReplies() + Fixture.treeReplies([]) + [
            .init("/graphql", ["message": "private note content test-token"], method: "POST", status: status)
        ]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [:])
        do {
            _ = try await Fixture.client(session).commit(
                changes: [VaultFileChange(path: "new.md", data: Data())],
                onto: snapshot
            )
            Issue.record("Expected a sanitized HTTP publication failure")
        } catch let VaultError.remote(message) {
            #expect(!message.contains("test-token") && !message.contains("private note content"))
        }
        #expect(GitHubVaultStub.recordedRequests.filter { $0.httpMethod != "GET" }.count == 1)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test
    func oversizedAtomicUploadNeverPublishesASubset() async throws {
        let replies = try Fixture.headReplies() + Fixture.treeReplies([])
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [:])
        let changes = [
            VaultFileChange(
                path: "Attachments/large.bin",
                data: Data(repeating: 0, count: GitHubVaultLimits.uploadBytes)
            ),
            VaultFileChange(path: "one.md", data: Data([0]))
        ]
        do {
            _ = try await Fixture.client(session).commit(changes: changes, onto: snapshot)
            Issue.record("Expected the total upload limit to reject the entire commit")
        } catch let VaultError.invalid(message) {
            #expect(message.contains("25 MiB total"))
        }
        #expect(GitHubVaultStub.recordedRequests.allSatisfy { $0.httpMethod == "GET" })
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test
    func unchangedContentAndMissingDeletionDoNotCreateAnEmptyCommit() async throws {
        let replies = try Fixture.headReplies() + Fixture.treeReplies([Fixture.entry("one.md")])
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let data = Data("hello".utf8)
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [
            "one.md": VaultRemoteFile(sha: Fixture.blob, data: data)
        ])
        let result = try await Fixture.client(session).commit(changes: [
            VaultFileChange(path: "one.md", data: data),
            VaultFileChange(path: "missing.md", data: nil)
        ], onto: snapshot)
        #expect(result == Fixture.head)
        #expect(GitHubVaultStub.recordedRequests.allSatisfy { $0.httpMethod == "GET" })
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test
    func truncatedTreesNeverBecomeDeletionSnapshots() async throws {
        let replies = try Fixture.headReplies() + Fixture.treeReplies([], truncated: true)
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        await #expect(throws: VaultError.self) { try await Fixture.client(session).fetch(cached: [:]) }
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: ["120000", "100644"])
    func rejectsLinksAndMalformedBlobContents(_ mode: String) async throws {
        var replies = try Fixture.headReplies() + Fixture.treeReplies([Fixture.entry("unsafe.md", mode: mode)])
        if mode == "100644" {
            try replies.append(.init("/blobs/\(Fixture.blob)", [
                "sha": Fixture.blob, "encoding": "base64", "size": 5, "content": "aGV!sbG8="
            ]))
        }
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        await #expect(throws: VaultError.self) { try await Fixture.client(session).fetch(cached: [:]) }
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: ["../escape.md", "unrelated.bin", "ONE.md", "one.md/child.md"])
    func unsafeAndCollidingWritesNeverUpload(_ path: String) async throws {
        let replies = try Fixture.headReplies() + Fixture.treeReplies([Fixture.entry("one.md")])
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = VaultRemoteSnapshot(headSHA: Fixture.head, treeSHA: Fixture.root, files: [
            "one.md": VaultRemoteFile(sha: Fixture.blob, data: Data("hello".utf8))
        ])
        await #expect(throws: VaultError.self) {
            try await Fixture.client(session).commit(
                changes: [VaultFileChange(path: path, data: Data())],
                onto: snapshot
            )
        }
        #expect(GitHubVaultStub.recordedRequests.allSatisfy { $0.httpMethod == "GET" })
    }

    @Test
    func missingFolderIsAnEmptyCompleteSnapshot() async throws {
        let replies = try Fixture.headReplies() + [.init(
            "/trees/\(Fixture.root)",
            Fixture.tree(Fixture.root, entries: [])
        )]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let snapshot = try await Fixture.client(session).fetch(cached: [:])
        #expect(snapshot.files.isEmpty)
        #expect(snapshot.treeSHA == Fixture.root)
        #expect(GitHubVaultStub.remainingReplies == 0)
    }

    @Test(arguments: [404, 409])
    func emptyOrMissingBranchGivesInitializationGuidance(_ status: Int) async throws {
        let replies = try [GitHubVaultStub.Reply("/ref/heads/feature/vault", ["message": "not logged"], status: status)]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        do {
            _ = try await Fixture.client(session).fetch(cached: [:])
            Issue.record("Expected a missing-branch error")
        } catch let VaultError.remote(message) {
            #expect(message.contains("Initialize"))
            #expect(!message.contains("test-token") && !message.contains("not logged"))
        }
    }

    @Test
    func redirectsAreRejectedWithoutForwardingCredentials() throws {
        let source = try #require(URL(string: "https://api.github.com/repos/owner/repo/git/ref/heads/main"))
        let foreign = try #require(URL(string: "https://example.com/stolen"))
        let response = try #require(HTTPURLResponse(
            url: source,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": foreign.absoluteString]
        ))
        let session = URLSession(configuration: .ephemeral)
        defer { session.invalidateAndCancel() }
        let task = session.dataTask(with: source)
        GitHubVaultRedirectGuard().urlSession(
            session,
            task: task,
            willPerformHTTPRedirection: response,
            newRequest: URLRequest(url: foreign)
        ) {
            #expect($0 == nil)
        }
        task.cancel()
    }

    @Test
    func branchComponentsArePercentEncodedWithoutChangingRefIdentity() async throws {
        var configuration = Fixture.configuration
        configuration.branch = "feature/vault#1%2"
        let reference: [String: Any] = [
            "ref": "refs/heads/\(configuration.branch)", "object": ["type": "commit", "sha": Fixture.head]
        ]
        let replies = try [
            GitHubVaultStub.Reply("/ref/heads/feature/vault#1%2", reference),
            .init("/commits/\(Fixture.head)", ["sha": Fixture.head, "tree": ["sha": Fixture.root]]),
            .init("/trees/\(Fixture.root)", Fixture.tree(Fixture.root, entries: []))
        ]
        let session = GitHubVaultStub.session(replies: replies)
        defer { session.invalidateAndCancel() }
        let client = GitHubVaultClient(configuration: configuration, token: "test-token", session: session)
        _ = try await client.fetch(cached: [:])
        let request = try #require(GitHubVaultStub.recordedRequests.first)
        #expect(request.url?.absoluteString.hasSuffix("/feature/vault%231%252") == true)
        #expect(request.url?.query == nil && request.url?.fragment == nil)
    }

    @Test
    func alreadyCancelledFetchDoesNotMakeRequests() async throws {
        let session = GitHubVaultStub.session(replies: [])
        defer { session.invalidateAndCancel() }
        let client = Fixture.client(session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.fetch(cached: [:])
        }
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(GitHubVaultStub.recordedRequests.isEmpty)
    }

    private func expectFileChanges(_ input: [String: Any], image: Data) throws {
        let files = try #require(input["fileChanges"] as? [String: Any])
        let additions = try #require(files["additions"] as? [[String: String]])
        #expect(additions == [
            ["path": "Notes/My Vault/one.md", "contents": Data("new".utf8).base64EncodedString()],
            ["path": "Notes/My Vault/Attachments/photo.png", "contents": image.base64EncodedString()]
        ])
        #expect(files["deletions"] as? [[String: String]] == [["path": "Notes/My Vault/delete.md"]])
    }
}
