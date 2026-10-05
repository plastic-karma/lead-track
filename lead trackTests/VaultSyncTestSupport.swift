import Foundation
@testable import lead_track

@MainActor
func makeEngine(
    _ store: VaultTestLocalStore, _ remote: VaultTestRemote, _ persistence: VaultTestState
) throws -> VaultSyncEngine {
    try VaultSyncEngine(
        configuration: VaultConfiguration(owner: "test", repository: "vault", branch: "main", folder: "LeadStone"),
        remote: remote, store: store, persistence: persistence
    )
}

@MainActor
final class VaultTestLocalStore: VaultLocalStore {
    var models = VaultModels(aspirations: [
        Aspiration(
            title: "Learn",
            detail: "Original description",
            createdAt: Date(timeIntervalSince1970: 1_750_000_000)
        )
    ])
    private var receipts: [String: UUID] = [:]

    func snapshot() throws -> VaultGraph {
        try VaultModelCodec.export(models)
    }

    func appliedTransaction(destination: String) throws -> UUID? {
        receipts[destination]
    }

    func apply(_ graph: VaultGraph, expecting expected: VaultGraph, transaction: VaultApplyTransaction) throws {
        guard try snapshot() == expected else { throw VaultError.conflict("Concurrent local edit") }
        models = try VaultModelCodec.apply(graph, to: models)
        receipts[transaction.destination] = transaction.id
    }
}

@MainActor
final class VaultTestState: VaultStatePersistence {
    var state: VaultSyncState?
    var failAcknowledgment = false
    func load(destination: String) throws -> VaultSyncState {
        state ?? VaultSyncState(destination: destination)
    }

    func save(_ state: VaultSyncState) throws {
        if failAcknowledgment, state.pending == nil {
            failAcknowledgment = false
            throw URLError(.cannotWriteToFile)
        }
        self.state = state
    }
}

actor VaultTestRemote: VaultRemote {
    private var files: [String: VaultRemoteFile] = [:]
    private var revision = 0
    private var loseAcknowledgment = false
    private var onCommit: (@Sendable () async -> Void)?

    func beforeNextCommit(_ action: @escaping @Sendable () async -> Void) {
        onCommit = action
    }

    func loseNextAcknowledgment() {
        loseAcknowledgment = true
    }

    func fetch(cached _: [String: VaultRemoteFile]) async throws -> VaultRemoteSnapshot {
        VaultRemoteSnapshot(headSHA: String(revision), treeSHA: String(revision), files: files)
    }

    func commit(changes: [VaultFileChange], onto snapshot: VaultRemoteSnapshot) async throws -> String {
        guard snapshot.headSHA == String(revision) else { throw VaultError.conflict("Stale revision") }
        if let onCommit {
            self.onCommit = nil
            await onCommit()
        }
        revision += 1
        for change in changes {
            files[change.path] = change.data.map { VaultRemoteFile(sha: String(revision), data: $0) }
        }
        if loseAcknowledgment {
            loseAcknowledgment = false
            throw URLError(.networkConnectionLost)
        }
        return String(revision)
    }

    func graph() throws -> VaultGraph {
        try ObsidianVaultCodec.decode(files.mapValues(\.data))
    }

    func replaceGraph(_ graph: VaultGraph) throws {
        let old = try self.graph()
        for record in old.records.values {
            files[record.path] = nil
        }
        for path in old.attachments.keys {
            files[path] = nil
        }
        revision += 1
        for (path, data) in try ObsidianVaultCodec.encode(graph) {
            files[path] = VaultRemoteFile(sha: String(revision), data: data)
        }
    }

    func replaceFile(_ path: String, data: Data) {
        revision += 1
        files[path] = VaultRemoteFile(sha: String(revision), data: data)
    }
}
