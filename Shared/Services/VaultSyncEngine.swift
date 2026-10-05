import Foundation

/// The phone is the only GitHub writer in the app family. SwiftData still serves
/// every offline read/write; this engine reconciles snapshots, never replaces it.
@MainActor
final class VaultSyncEngine {
    private let remote: any VaultRemote
    private let store: any VaultLocalStore
    private let persistence: any VaultStatePersistence
    private let configuration: VaultConfiguration
    private var state: VaultSyncState
    private var running = false

    init(
        configuration: VaultConfiguration, remote: any VaultRemote,
        store: any VaultLocalStore, persistence: any VaultStatePersistence
    ) throws {
        self.remote = remote
        self.store = store
        self.persistence = persistence
        self.configuration = try configuration.validated()
        state = try persistence.load(destination: self.configuration.identity)
    }

    func synchronize(resolutions: [String: VaultResolution] = [:]) async throws -> VaultSyncOutcome {
        guard !running else { throw VaultError.conflict("A vault sync is already in progress.") }
        running = true
        defer { running = false }
        try Task.checkCancellation()
        if state.pending?.published == true {
            var outcome = try finish(resolutions: resolutions)
            outcome.needsSync = outcome.conflicts.isEmpty
            return outcome
        }
        let snapshot = try await remote.fetch(cached: state.files)
        try Task.checkCancellation()
        let remoteGraph = try ObsidianVaultCodec.decode(snapshot.files.mapValues(\.data), folder: configuration.folder)
        try checkTrackedNotes(remoteGraph, snapshot: snapshot)
        if var pending = state.pending, pending.target == remoteGraph {
            pending.files = snapshot.files
            pending.published = true
            state.pending = pending
            try persistence.save(state)
            return try finish(resolutions: resolutions)
        }
        return try await reconcile(remoteGraph, snapshot: snapshot, resolutions: resolutions)
    }

    private func checkTrackedNotes(_ graph: VaultGraph, snapshot: VaultRemoteSnapshot) throws {
        for record in state.baseline.records.values
            where graph.records[record.id] == nil && snapshot.files[record.path] != nil
        {
            throw VaultError.invalid(
                "A synced note lost or changed its LeadStone identity: \(record.path). "
                    + "Restore its frontmatter, or delete the file to remove the record."
            )
        }
    }

    private func reconcile(
        _ remoteGraph: VaultGraph, snapshot: VaultRemoteSnapshot, resolutions: [String: VaultResolution]
    ) async throws -> VaultSyncOutcome {
        let local = try atStage(.localSnapshot) { try capture().normalized }
        var merger = VaultMerge(resolutions: resolutions)
        var result = try merger.merge(base: state.baseline, local: local, remote: remoteGraph)
        if let pending = state.pending {
            let recovery = VaultUncertainPublication(
                baseline: state.baseline, target: pending.target, resolutions: resolutions
            )
            result = recovery.reconcile(result, local: local, remote: remoteGraph)
        }
        guard result.conflicts.isEmpty else { return VaultSyncOutcome(conflicts: result.conflicts) }
        let target = try VaultPublicationLinks.rewrite(result.graph, folder: configuration.folder)
        let projection = try atStage(.syncSnapshot) {
            try VaultModelCodec.export(VaultModelCodec.materialize(target))
        }
        let plan = try VaultSyncPlan(graph: target, remoteGraph: remoteGraph, snapshot: snapshot)
        state.pending = VaultPendingSync(source: local, target: target, projection: projection, files: plan.files)
        state.pending?.published = plan.changes.isEmpty
        try persistence.save(state)
        try Task.checkCancellation()
        if !plan.changes.isEmpty { _ = try await remote.commit(changes: plan.changes, onto: snapshot) }
        state.pending?.published = true
        try persistence.save(state)
        try Task.checkCancellation()
        return try finish(resolutions: [:])
    }

    private func finish(resolutions: [String: VaultResolution]) throws -> VaultSyncOutcome {
        try Task.checkCancellation()
        guard let pending = state.pending else { return VaultSyncOutcome(date: state.lastSyncedAt) }
        if try store.appliedTransaction(destination: state.destination) == pending.transactionID {
            try acknowledge(pending)
            return VaultSyncOutcome(needsSync: true, date: state.lastSyncedAt)
        }
        let current = try atStage(.localRecheck) { try capture() }
        var merger = VaultMerge(resolutions: resolutions)
        let result = try merger.merge(base: pending.source, local: current.normalized, remote: pending.target)
        guard result.conflicts.isEmpty else { return VaultSyncOutcome(conflicts: result.conflicts) }
        if result.graph != current.normalized {
            let transaction = VaultApplyTransaction(id: pending.transactionID, destination: state.destination)
            try atStage(.localApply) {
                try store.apply(result.graph, expecting: current.raw, transaction: transaction)
            }
        }
        try acknowledge(pending)
        return VaultSyncOutcome(needsSync: result.graph != pending.target, date: state.lastSyncedAt)
    }

    private func capture() throws -> (raw: VaultGraph, normalized: VaultGraph) {
        let raw = try store.snapshot()
        var normalized = VaultLocalChanges.overlay(snapshot: raw, base: state.baseline, projection: state.projection)
        normalized.attachmentRoot = configuration.folder
        return (raw, normalized)
    }

    private func atStage<Value>(_ stage: VaultSyncFailure.Stage, _ operation: () throws -> Value) throws -> Value {
        do {
            return try operation()
        } catch let error as VaultError {
            throw VaultSyncFailure(stage: stage, underlying: error)
        }
    }

    private func acknowledge(_ pending: VaultPendingSync) throws {
        var acknowledged = state
        acknowledged.baseline = pending.target
        acknowledged.projection = pending.projection
        acknowledged.files = pending.files
        acknowledged.pending = nil
        acknowledged.lastSyncedAt = .now
        try persistence.save(acknowledged)
        state = acknowledged
    }
}
