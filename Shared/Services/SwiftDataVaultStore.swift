#if canImport(SwiftData)
import Foundation
import SwiftData

@MainActor
struct SwiftDataVaultStore {
    let context: ModelContext
    private let didApply: (() -> Void)?

    init(context: ModelContext, didApply: (() -> Void)? = nil) {
        self.context = context
        self.didApply = didApply
    }

    func snapshot() throws -> VaultGraph {
        let models = try fetchModels()
        let graph = try VaultModelCodec.export(models)
        if context.hasChanges { try context.save() }
        return graph
    }

    func appliedTransaction(destination: String) throws -> UUID? {
        try receipt(destination: destination)?.transactionID
    }

    func apply(_ graph: VaultGraph, expecting expected: VaultGraph, transaction: VaultApplyTransaction) throws {
        // No fetched or registered object is touched until every field, attachment,
        // relation and domain invariant has been checked on detached objects.
        let staged = try VaultModelCodec.materialize(graph)
        // Preserve pending user edits if a later persistence failure rolls back.
        if context.hasChanges { try context.save() }
        do {
            try context.transaction {
                let existing = try fetchModels()
                // Export normally backfills legacy IDs. An unrecognized row here
                // is an intervening local change, not permission to mutate it.
                guard existing.all.allSatisfy({ $0.stableID != nil }),
                      try VaultModelCodec.export(existing) == expected
                else {
                    throw VaultError.conflict("Local records changed during sync. Sync again to reconcile them.")
                }
                let priorReceipt = try receipt(destination: transaction.destination)
                try reconcile(graph, staged: staged, existing: existing, expected: expected)
                if let priorReceipt {
                    priorReceipt.transactionID = transaction.id
                } else {
                    context.insert(VaultSyncReceipt(
                        destination: transaction.destination,
                        transactionID: transaction.id
                    ))
                }
                try context.save()
            }
        } catch {
            context.rollback()
            throw error
        }
        didApply?()
    }

    private func receipt(destination: String) throws -> VaultSyncReceipt? {
        var descriptor = FetchDescriptor<VaultSyncReceipt>(
            predicate: #Predicate { $0.destination == destination }
        )
        descriptor.fetchLimit = 2
        let receipts = try context.fetch(descriptor)
        guard receipts.count <= 1 else {
            throw VaultError.invalid("Duplicate local sync receipts for this destination")
        }
        return receipts.first
    }

    private func reconcile(
        _ graph: VaultGraph,
        staged: VaultModels,
        existing: VaultModels,
        expected: VaultGraph
    ) throws {
        let desired = try VaultModelCodec.reconcile(graph, staged: staged, existing: existing)
        for model in desired.all {
            if let id = model.stableID, expected.records[id] == nil { insert(model) }
        }
        // Delete only identities that the engine explicitly reconciled, never
        // every fetched row absent from a potentially older target graph.
        for model in existing.all {
            if let id = model.stableID, expected.records[id] != nil, graph.records[id] == nil { delete(model) }
        }
    }

    private func fetchModels() throws -> VaultModels {
        try VaultModels(
            aspirations: context.fetch(FetchDescriptor<Aspiration>()),
            metrics: context.fetch(FetchDescriptor<Metric>()),
            projects: context.fetch(FetchDescriptor<Project>()),
            sessions: context.fetch(FetchDescriptor<Session>()),
            principles: context.fetch(FetchDescriptor<Principle>()),
            intentions: context.fetch(FetchDescriptor<Intention>()),
            checkIns: context.fetch(FetchDescriptor<AspirationCheckIn>()),
            moments: context.fetch(FetchDescriptor<Moment>()),
            photos: context.fetch(FetchDescriptor<MomentPhoto>())
        )
    }

    private func insert(_ model: any VaultModel) {
        switch model {
        case let value as Aspiration: context.insert(value)
        case let value as Metric: context.insert(value)
        case let value as Project: context.insert(value)
        case let value as Session: context.insert(value)
        case let value as Principle: context.insert(value)
        case let value as Intention: context.insert(value)
        case let value as AspirationCheckIn: context.insert(value)
        case let value as Moment: context.insert(value)
        case let value as MomentPhoto: context.insert(value)
        default: break
        }
    }

    private func delete(_ model: any VaultModel) {
        switch model {
        case let value as Aspiration: context.delete(value)
        case let value as Metric: context.delete(value)
        case let value as Project: context.delete(value)
        case let value as Session: context.delete(value)
        case let value as Principle: context.delete(value)
        case let value as Intention: context.delete(value)
        case let value as AspirationCheckIn: context.delete(value)
        case let value as Moment: context.delete(value)
        case let value as MomentPhoto: context.delete(value)
        default: break
        }
    }
}
#endif
