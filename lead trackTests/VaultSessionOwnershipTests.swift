import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

@MainActor
struct VaultSessionOwnershipTests {
    private let instant = Date(timeIntervalSince1970: 1_750_000_000)

    @Test(arguments: [MeasurementType.duration, .count, .binary])
    func projectMetricExportsExplicitlyWithoutMutatingTheSession(_ type: MeasurementType) throws {
        let models = projectOwnedModels(type)
        let session = try #require(models.sessions.first)
        let metric = try #require(models.metrics.first)
        let project = try #require(models.projects.first)
        let graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)
        let record = try #require(graph.records[id])
        #expect(record.fields["metric"] == VaultModelLinks.linkID(metric.stableID))
        #expect(record.fields["project"] == VaultModelLinks.linkID(project.stableID))
        #expect(session.metric == nil)
        #expect(session.project === project)
        #expect(try VaultModelCodec.export(VaultModelCodec.materialize(graph)) == graph)
    }

    @Test(arguments: [MeasurementType.count, .binary])
    func projectOwnedValuesStillRespectMeasurementType(_ type: MeasurementType) throws {
        let models = projectOwnedModels(type)
        let session = try #require(models.sessions.first)
        session.value = type == .count ? nil : 2
        #expect(throws: VaultError.self) { try VaultModelCodec.export(models) }
    }

    @Test
    func projectOwnedTimersCountTowardMetricUniqueness() throws {
        var models = projectOwnedModels(.duration, running: true)
        let metric = try #require(models.metrics.first)
        models.sessions.append(Session(metric: metric, startedAt: instant))
        #expect(throws: VaultError.self) { try VaultModelCodec.export(models) }
    }

    @Test
    func projectOwnedRunningTimerPreservesItsCountdownAndOwner() throws {
        let models = projectOwnedModels(.duration, running: true)
        let restored = try VaultModelCodec.materialize(VaultModelCodec.export(models))
        let session = try #require(restored.sessions.first)
        #expect(session.isRunning)
        #expect(session.countdownDuration == 300)
        #expect(session.startedAt == instant)
        #expect(session.metric?.stableID == models.metrics.first?.stableID)
        #expect(session.project?.stableID == models.projects.first?.stableID)
    }

    @Test
    func sessionWithoutAnyResolvableMetricRemainsRejected() {
        let session = Session(startedAt: instant, endedAt: instant.addingTimeInterval(60))
        let models = VaultModels(sessions: [session])
        #expect(throws: VaultError.self) { try VaultModelCodec.export(models) }
    }

    #if canImport(SwiftData)
    @Test
    func savedProjectOwnedSessionExportsWithoutRewritingItsRelationships() throws {
        let fixture = try ModelFixture()
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let metric = Metric(name: "Reading", measurementType: .count, createdAt: date)
        let project = Project(name: "Book", metric: metric, startedAt: date)
        let session = Session(project: project, startedAt: date, endedAt: date, value: 7)
        fixture.context.insert(metric)
        fixture.context.insert(project)
        fixture.context.insert(session)
        try fixture.context.save()
        let reader = ModelContext(fixture.context.container)
        let saved = try #require(reader.fetch(FetchDescriptor<Session>()).first)
        #expect(saved.metric == nil)
        let store = SwiftDataVaultStore(context: reader)
        let graph = try store.snapshot()
        let id = try #require(saved.stableID)
        let record = try #require(graph.records[id])
        #expect(record.fields["metric"] == VaultModelLinks.linkID(metric.stableID))
        #expect(record.fields["project"] == VaultModelLinks.linkID(project.stableID))
        #expect(record.fields["value"] == .number(7))
        #expect(saved.metric == nil)
        let reopened = SwiftDataVaultStore(context: ModelContext(fixture.context.container))
        #expect(try reopened.snapshot() == graph)
    }
    #endif

    private func projectOwnedModels(_ type: MeasurementType, running: Bool = false) -> VaultModels {
        let metric = Metric(name: "Reading", measurementType: type, createdAt: instant)
        let project = Project(name: "Book", metric: metric, startedAt: instant)
        let value: Double? = switch type {
        case .duration: nil
        case .count: 7
        case .binary: 1
        }
        let session = Session(
            project: project, startedAt: instant,
            endedAt: running ? nil : instant.addingTimeInterval(60), value: value,
            countdownDuration: type == .duration ? 300 : nil
        )
        return VaultModels(metrics: [metric], projects: [project], sessions: [session])
    }
}
