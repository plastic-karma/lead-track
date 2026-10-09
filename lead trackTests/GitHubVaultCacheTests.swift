import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import lead_track

extension GitHubVaultClientTests {
    @Test
    @MainActor
    func interruptedPublicationReusesBlobsAcrossConflictedRestarts() async throws {
        let fixture = try VaultCacheFixture()
        let session = try GitHubVaultStub.session(replies: fixture.replies())
        defer { session.invalidateAndCancel() }
        let first = try await fixture.synchronize(session: session)
        let second = try await fixture.synchronize(session: session)
        #expect(first.conflicts.map(\.local) == [.record(fixture.localRecord)])
        #expect(first.conflicts.map(\.remote) == [.record(fixture.remoteRecord)])
        #expect(second.conflicts == first.conflicts)
        let downloads = GitHubVaultStub.recordedRequests.filter { $0.url?.path.contains("/blobs/") == true }
        #expect(downloads.count == 1)
        #expect(downloads.first?.url?.path.hasSuffix(GitHubVaultFixture.blob) == true)
        #expect(GitHubVaultStub.recordedRequests.allSatisfy { $0.httpMethod == "GET" })
        #expect(fixture.persistence.state?.baseline == fixture.baseline)
        #expect(fixture.persistence.state?.lastSyncedAt == fixture.instant)
        #expect(fixture.persistence.state?.pending?.published == false)
        #expect(fixture.store.models.aspirations.first?.title == "Phone edit")
    }
}

@MainActor
private struct VaultCacheFixture {
    private typealias Fixture = GitHubVaultFixture
    let store = VaultTestLocalStore()
    let persistence = VaultTestState()
    let instant = Date(timeIntervalSince1970: 1_750_000_000)
    let baseline: VaultGraph
    let remoteRecord: VaultRecord
    let localRecord: VaultRecord
    private let files: [String: VaultRemoteFile]

    init() throws {
        let aspiration = try #require(store.models.aspirations.first)
        store.models = VaultModels(aspirations: [aspiration, Aspiration(title: "Keep", createdAt: instant)])
        let projection = try store.snapshot()
        baseline = try ObsidianVaultCodec.decode(
            ObsidianVaultCodec.encode(projection), folder: Fixture.configuration.folder
        )
        remoteRecord = try #require(baseline.records.values.first { $0.fields["title"] == .string("Learn") })
        aspiration.title = "Phone edit"
        let local = try store.snapshot()
        let normalized = VaultLocalChanges.overlay(snapshot: local, base: baseline, projection: projection)
        let target = try VaultPublicationLinks.rewrite(normalized, folder: Fixture.configuration.folder)
        localRecord = try #require(target.records[remoteRecord.id])
        files = try Self.remoteFiles(baseline, changedPath: remoteRecord.path)
        var pendingFiles = files
        let encoded = try ObsidianVaultCodec.encode(target)
        pendingFiles[localRecord.path] = try VaultRemoteFile(sha: "", data: #require(encoded[localRecord.path]))
        persistence.state = VaultSyncState(
            destination: Fixture.configuration.identity, baseline: baseline, projection: projection,
            files: files.mapValues { VaultRemoteFile(sha: "", data: $0.data) },
            pending: VaultPendingSync(source: target, target: target, projection: local, files: pendingFiles),
            lastSyncedAt: instant
        )
    }

    func synchronize(session: URLSession) async throws -> VaultSyncOutcome {
        let engine = try VaultSyncEngine(
            configuration: Fixture.configuration, remote: Fixture.client(session),
            store: store, persistence: persistence
        )
        return try await engine.synchronize()
    }

    func replies() throws -> [GitHubVaultStub.Reply] {
        let entries = [Fixture.entry("Aspirations", sha: String(repeating: "8", count: 40), mode: "040000")]
            + files.map { Fixture.entry($0.key, sha: $0.value.sha, size: $0.value.data.count) }
        let fetch = try Fixture.headReplies() + Fixture.treeReplies(entries)
        let missing = try #require(files[remoteRecord.path])
        return try fetch + [Fixture.blobReply(missing.sha, data: missing.data)] + fetch
    }

    private static func remoteFiles(_ graph: VaultGraph, changedPath: String) throws -> [String: VaultRemoteFile] {
        let encoded = try ObsidianVaultCodec.encode(graph)
        var files = encoded.mapValues { VaultRemoteFile(sha: Fixture.other, data: $0) }
        files[changedPath] = try VaultRemoteFile(sha: Fixture.blob, data: #require(encoded[changedPath]))
        return files
    }
}
