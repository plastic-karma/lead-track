#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import lead_track

@MainActor
struct SwiftDataVaultStoreTests {
    private let destination = "owner/repository/main/LeadStone"

    private func transaction() -> VaultApplyTransaction {
        VaultApplyTransaction(id: UUID(), destination: destination)
    }

    @Test
    func freshStoreImportsUpdatesAndDeletesRealModels() throws {
        let fixture = try ModelFixture()
        let store = SwiftDataVaultStore(context: fixture.context)
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let aspiration = Aspiration(title: "Read deeply", detail: "Original", createdAt: date)
        let metric = Metric(name: "Reading", createdAt: date)
        let session = Session(metric: metric, startedAt: date, endedAt: date.addingTimeInterval(60))
        aspiration.metrics = [metric]
        var graph = try VaultModelCodec.export(VaultModels(
            aspirations: [aspiration],
            metrics: [metric],
            sessions: [session]
        ))
        try store.apply(graph, expecting: VaultGraph(), transaction: transaction())
        #expect(try fixture.context.fetch(FetchDescriptor<Session>()).count == 1)
        #expect(try store.snapshot() == graph)
        let aspirationID = try #require(aspiration.stableID)
        let imported = try store.snapshot()
        graph.records[aspirationID]?.body = "Changed from Obsidian\n"
        try store.apply(graph, expecting: imported, transaction: transaction())
        let saved = try #require(fixture.context.fetch(FetchDescriptor<Aspiration>()).first)
        #expect(saved.detail == "Changed from Obsidian\n")
        let updated = try store.snapshot()
        try graph.records.removeValue(forKey: #require(session.stableID))
        try store.apply(graph, expecting: updated, transaction: transaction())
        #expect(try fixture.context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try store.snapshot() == graph)
    }

    @Test
    func reparentBeforeDeletingCascadeOwnerKeepsSurvivingPhoto() throws {
        let fixture = try ModelFixture()
        let store = SwiftDataVaultStore(context: fixture.context)
        let old = Aspiration(title: "Old")
        let replacement = Aspiration(title: "Replacement")
        let moment = Moment(text: "Kept", aspiration: old)
        let photo = MomentPhoto(data: Data([0xFF, 0xD8, 0xFF, 0]), moment: moment)
        let original = try VaultModelCodec.export(VaultModels(aspirations: [old], moments: [moment], photos: [photo]))
        try store.apply(original, expecting: VaultGraph(), transaction: transaction())
        var changed = original
        try changed.records.removeValue(forKey: #require(old.stableID))
        let replacementGraph = try VaultModelCodec.export(VaultModels(aspirations: [replacement]))
        changed.records.merge(replacementGraph.records) { _, new in new }
        try changed.records[#require(moment.stableID)]?.fields["aspiration"] = VaultModelLinks
            .linkID(replacement.stableID)
        let applied = transaction()
        try store.apply(changed, expecting: original, transaction: applied)
        #expect(try fixture.context.fetch(FetchDescriptor<Aspiration>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<Moment>()).count == 1)
        #expect(try fixture.context.fetch(FetchDescriptor<MomentPhoto>()).count == 1)
        #expect(try store.snapshot() == changed)
        #expect(try store.appliedTransaction(destination: destination) == applied.id)
    }

    @Test
    func invalidGraphDoesNotDeleteExistingRowsAndIDsAreSaved() throws {
        let fixture = try ModelFixture()
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("Book", of: metric)
        project.stableID = nil
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let id = try #require(project.stableID)
        #expect(!fixture.context.hasChanges)
        let previous = transaction()
        try store.apply(baseline, expecting: baseline, transaction: previous)
        var invalid = baseline
        try invalid.records.removeValue(forKey: #require(metric.stableID))
        #expect(throws: (any Error).self) {
            try store.apply(invalid, expecting: baseline, transaction: transaction())
        }
        #expect(try fixture.context.fetch(FetchDescriptor<Project>()).first?.stableID == id)
        #expect(try store.snapshot() == baseline)
        #expect(try store.appliedTransaction(destination: destination) == previous.id)
    }

    @Test
    func successfulApplyPersistsGraphAndReceiptTogether() throws {
        let fixture = try ModelFixture()
        let store = SwiftDataVaultStore(context: fixture.context)
        let aspiration = Aspiration(title: "Published")
        let graph = try VaultModelCodec.export(VaultModels(aspirations: [aspiration]))
        let first = transaction()
        try store.apply(graph, expecting: VaultGraph(), transaction: first)
        let reader = SwiftDataVaultStore(context: ModelContext(fixture.context.container))
        #expect(try reader.snapshot() == graph)
        #expect(try reader.appliedTransaction(destination: destination) == first.id)
        #expect(try reader.appliedTransaction(destination: "another/destination") == nil)

        let second = transaction()
        try store.apply(VaultGraph(), expecting: graph, transaction: second)
        let finalContext = ModelContext(fixture.context.container)
        let finalStore = SwiftDataVaultStore(context: finalContext)
        #expect(try finalStore.snapshot() == VaultGraph())
        #expect(try finalStore.appliedTransaction(destination: destination) == second.id)
        #expect(try finalContext.fetch(FetchDescriptor<VaultSyncReceipt>()).count == 1)
    }

    @Test
    func concurrentlySavedSessionRejectsApplyWithoutDeletingUserData() throws {
        let fixture = try ModelFixture()
        _ = fixture.makeMetric()
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let writer = ModelContext(fixture.context.container)
        let metric = try #require(writer.fetch(FetchDescriptor<Metric>()).first)
        let session = Session(metric: metric, value: 7)
        writer.insert(session)
        try writer.save()
        let concurrent = try SwiftDataVaultStore(context: writer).snapshot()

        do {
            try store.apply(VaultGraph(), expecting: baseline, transaction: transaction())
            Issue.record("Expected an intervening-session conflict")
        } catch VaultError.conflict {}

        let reader = SwiftDataVaultStore(context: ModelContext(fixture.context.container))
        #expect(try reader.snapshot() == concurrent)
        #expect(try reader.appliedTransaction(destination: destination) == nil)
    }

    @Test
    func concurrentlySavedMomentRejectsApplyWithoutDeletingUserData() throws {
        let fixture = try ModelFixture()
        _ = fixture.makeAspiration()
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let writer = ModelContext(fixture.context.container)
        let aspiration = try #require(writer.fetch(FetchDescriptor<Aspiration>()).first)
        let moment = Moment(text: "Kept from the share extension", aspiration: aspiration)
        writer.insert(moment)
        writer.insert(MomentPhoto(data: Data([0xFF, 0xD8, 0xFF, 0]), moment: moment))
        try writer.save()
        let concurrent = try SwiftDataVaultStore(context: writer).snapshot()

        do {
            try store.apply(VaultGraph(), expecting: baseline, transaction: transaction())
            Issue.record("Expected an intervening-moment conflict")
        } catch VaultError.conflict {}

        let reader = SwiftDataVaultStore(context: ModelContext(fixture.context.container))
        #expect(try reader.snapshot() == concurrent)
        #expect(try reader.appliedTransaction(destination: destination) == nil)
    }

    @Test
    func pendingOrdinaryEditsSurviveConflictAndReceiptDoesNotAdvance() throws {
        let fixture = try ModelFixture()
        let metric = fixture.makeMetric()
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let previous = transaction()
        try store.apply(baseline, expecting: baseline, transaction: previous)
        metric.name = "Edited while publishing"

        do {
            try store.apply(VaultGraph(), expecting: baseline, transaction: transaction())
            Issue.record("Expected an intervening-edit conflict")
        } catch VaultError.conflict {}

        #expect(metric.name == "Edited while publishing")
        let readerContext = ModelContext(fixture.context.container)
        #expect(try readerContext.fetch(FetchDescriptor<Metric>()).first?.name == "Edited while publishing")
        let reader = SwiftDataVaultStore(context: readerContext)
        #expect(try reader.appliedTransaction(destination: destination) == previous.id)
        #expect(try reader.snapshot().records.count == baseline.records.count)
    }

    @Test
    func unbackfilledConcurrentRowIsRejectedWithoutAssigningIdentity() throws {
        let fixture = try ModelFixture()
        let metric = fixture.makeMetric()
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let session = Session(metric: metric, value: 3)
        session.stableID = nil
        fixture.context.insert(session)

        do {
            try store.apply(VaultGraph(), expecting: baseline, transaction: transaction())
            Issue.record("Expected an unrecognized-row conflict")
        } catch VaultError.conflict {}

        #expect(session.stableID == nil)
        let reader = ModelContext(fixture.context.container)
        #expect(try reader.fetch(FetchDescriptor<Session>()).count == 1)
        #expect(try reader.fetch(FetchDescriptor<Session>()).first?.stableID == nil)
        #expect(try reader.fetch(FetchDescriptor<VaultSyncReceipt>()).isEmpty)
    }

    @Test
    func duplicateDestinationReceiptsRejectReadsAndApplyWithoutMutation() throws {
        let fixture = try ModelFixture()
        _ = fixture.makeMetric()
        let store = SwiftDataVaultStore(context: fixture.context)
        let baseline = try store.snapshot()
        let first = transaction()
        let second = transaction()
        fixture.context.insert(VaultSyncReceipt(destination: destination, transactionID: first.id))
        fixture.context.insert(VaultSyncReceipt(destination: destination, transactionID: second.id))
        try fixture.context.save()

        #expect(throws: VaultError.self) { try store.appliedTransaction(destination: destination) }
        #expect(throws: VaultError.self) {
            try store.apply(VaultGraph(), expecting: baseline, transaction: transaction())
        }
        #expect(try store.snapshot() == baseline)
        let receipts = try fixture.context.fetch(FetchDescriptor<VaultSyncReceipt>())
        #expect(Set(receipts.map(\.transactionID)) == Set([first.id, second.id]))
    }
}
#endif
