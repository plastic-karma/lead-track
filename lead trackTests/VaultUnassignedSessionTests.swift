import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultUnassignedSessionTests {
    private let instant = Date(timeIntervalSince1970: 1_750_000_000)

    enum Shape: CaseIterable {
        case point, duration, running, countdown
    }

    @Test(arguments: Shape.allCases)
    func markdownRoundTripAndApplyPreserveUnassignedData(_ shape: Shape) throws {
        let session = makeSession(shape)
        let models = VaultModels(sessions: [session])
        let graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)
        let record = try #require(graph.records[id])
        #expect(record.fields["metric"] == .null)
        #expect(record.fields["project"] == .null)
        let decoded = try markdownRoundTrip(graph)
        let restored = try VaultModelCodec.materialize(decoded)
        #expect(restored.metrics.isEmpty && restored.projects.isEmpty)
        #expect(restored.sessions.count == 1)
        let copy = try #require(restored.sessions.first)
        #expect(copy.stableID == id)
        #expect(copy.metric == nil && copy.project == nil)
        #expect(copy.startedAt == session.startedAt && copy.endedAt == session.endedAt)
        #expect(copy.value == session.value && copy.countdownDuration == session.countdownDuration)
        let applied = try VaultModelCodec.apply(decoded, to: models)
        #expect(applied.sessions.first === session)
        #expect(try VaultModelCodec.export(applied) == graph)
    }

    @Test
    func unassignedNoteCanAcquireAndReleaseARealMetric() throws {
        let session = makeSession(.point)
        let metric = Metric(name: "Pages", measurementType: .count, createdAt: instant)
        let models = VaultModels(metrics: [metric], sessions: [session])
        var graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)
        graph.records[id]?.fields["metric"] = VaultModelLinks.linkID(metric.stableID)
        let assigned = try VaultModelCodec.apply(markdownRoundTrip(graph), to: models)
        #expect(assigned.sessions.first === session)
        #expect(session.metric === metric)
        graph = try VaultModelCodec.export(assigned)
        graph.records[id]?.fields["metric"] = .null
        let unassigned = try VaultModelCodec.apply(markdownRoundTrip(graph), to: assigned)
        #expect(unassigned.sessions.first === session)
        #expect(session.metric == nil && session.project == nil)
        #expect(session.stableID == id && session.value == 7)
        #expect(session.startedAt == instant && session.endedAt == instant)
        #expect(unassigned.metrics.count == 1 && unassigned.metrics.first === metric)
        #expect(!metric.sessions.contains { $0 === session })
    }

    @Test(arguments: ["metric", "project"], [false, true])
    func suppliedOwnershipLinksMustResolveToTheRightKind(_ field: String, dangling: Bool) throws {
        let session = makeSession(.point)
        let models = VaultModels(sessions: [session])
        let before = try VaultModelCodec.export(models)
        var graph = before
        let id = try #require(session.stableID)
        graph.records[id]?.fields[field] = VaultModelLinks.linkID(dangling ? UUID() : id)
        #expect(throws: VaultError.self) { try VaultModelCodec.materialize(markdownRoundTrip(graph)) }
        #expect(throws: VaultError.self) { try VaultModelCodec.apply(graph, to: models) }
        #expect(try VaultModelCodec.export(models) == before)
    }

    enum InvalidScalar: CaseIterable {
        case negativeValue, nonfiniteValue, reversedDates, futureStart, futureEnd
        case zeroCountdown, negativeCountdown, nonfiniteCountdown
    }

    @Test(arguments: InvalidScalar.allCases)
    func unassignedScalarsAreValidatedOnExportAndImport(_ invalid: InvalidScalar) throws {
        let session = makeSession(.duration)
        let models = VaultModels(sessions: [session])
        var graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)
        corrupt(session, with: invalid)
        graph.records[id]?.fields["value"] = session.value.vaultValue
        graph.records[id]?.fields["started_at"] = session.startedAt.vaultValue
        graph.records[id]?.fields["ended_at"] = session.endedAt.vaultValue
        graph.records[id]?.fields["countdown_duration"] = session.countdownDuration.vaultValue
        #expect(throws: VaultError.self) { try VaultModelCodec.export(models) }
        #expect(throws: VaultError.self) { try VaultModelCodec.materialize(graph) }
    }

    @Test
    func multipleUnassignedTimersDoNotCompeteWithAnOwnedTimer() throws {
        let metric = Metric(name: "Practice", measurementType: .duration, createdAt: instant)
        let owned = Session(metric: metric, startedAt: instant)
        let models = VaultModels(metrics: [metric], sessions: [owned, makeSession(.running), makeSession(.countdown)])
        var graph = try markdownRoundTrip(VaultModelCodec.export(models))
        #expect(try VaultModelCodec.materialize(graph).sessions.count == 3)
        let id = try #require(models.sessions[1].stableID)
        graph.records[id]?.fields["metric"] = VaultModelLinks.linkID(metric.stableID)
        #expect(throws: VaultError.self) { try VaultModelCodec.materialize(graph) }
    }

    @Test(arguments: [MeasurementType.count, .binary], [Shape.running, .duration])
    func assigningUnassignedTimersEnforcesMeasurementRules(_ type: MeasurementType, shape: Shape) throws {
        let metric = Metric(name: "Points", measurementType: type, createdAt: instant)
        let session = makeSession(shape)
        if shape == .duration { session.countdownDuration = 300 }
        let models = VaultModels(metrics: [metric], sessions: [session])
        var graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)
        if shape == .duration { graph.records[id]?.fields["value"] = .number(1) }
        graph.records[id]?.fields["metric"] = VaultModelLinks.linkID(metric.stableID)
        #expect(throws: VaultError.self) { try VaultModelCodec.materialize(graph) }
    }

    @Test
    func initialSyncPublishesOwnedAndUnassignedRecordsWithoutReplacingLocalObjects() async throws {
        let metric = Metric(name: "Pages", measurementType: .count, createdAt: instant)
        let owned = Session(metric: metric, startedAt: instant, endedAt: instant, value: 3)
        let unassigned = makeSession(.point)
        let local = VaultTestLocalStore()
        local.models = VaultModels(metrics: [metric], sessions: [owned, unassigned])
        let before = try local.snapshot()
        let id = try #require(unassigned.stableID)
        let remote = VaultTestRemote()
        let persistence = VaultTestState()
        let result = try await makeEngine(local, remote, persistence).synchronize()
        #expect(result.conflicts.isEmpty && !result.needsSync)
        let published = try await remote.graph()
        #expect(try VaultModelCodec.export(VaultModelCodec.materialize(published)) == before)
        #expect(published.records[id]?.fields["metric"] == .null)
        #expect(published.records[id]?.fields["project"] == .null)
        #expect(local.models.sessions.contains { $0 === owned })
        #expect(local.models.sessions.contains { $0 === unassigned })
        #expect(try local.snapshot() == before)
        #expect(persistence.state?.baseline.records == published.records)
        #expect(persistence.state?.pending == nil)
        let revision = try await remote.fetch(cached: [:]).headSHA
        let second = try await makeEngine(local, remote, persistence).synchronize()
        #expect(second.conflicts.isEmpty && !second.needsSync)
        #expect(try await remote.fetch(cached: [:]).headSHA == revision)
        #expect(try await remote.graph() == published)
        #expect(try local.snapshot() == before)
        #expect(local.models.sessions.contains { $0 === unassigned })
    }

    #if !canImport(SwiftData) // Native inverses cannot be made stale independently of their forward links.
    @Test
    func staleBacklinksCannotAssignAnUnassignedSession() throws {
        let session = makeSession(.point)
        let metric = Metric(name: "Unrelated", measurementType: .count, createdAt: instant)
        let project = Project(name: "Unrelated project", metric: metric, startedAt: instant)
        metric.sessions = [session]
        project.sessions = [session]
        let models = VaultModels(metrics: [metric], projects: [project], sessions: [session])

        let graph = try VaultModelCodec.export(models)
        let id = try #require(session.stableID)

        #expect(graph.records[id]?.fields["metric"] == .null)
        #expect(graph.records[id]?.fields["project"] == .null)
        #expect(session.metric == nil && session.project == nil)
        #expect(session.value == 7 && session.startedAt == instant && session.endedAt == instant)
    }
    #endif

    private func makeSession(_ shape: Shape) -> Session {
        switch shape {
        case .point:
            Session(startedAt: instant, endedAt: instant, value: 7)
        case .duration:
            Session(startedAt: instant, endedAt: instant.addingTimeInterval(90))
        case .running:
            Session(startedAt: instant)
        case .countdown:
            Session(startedAt: instant, countdownDuration: 300)
        }
    }

    private func markdownRoundTrip(_ graph: VaultGraph) throws -> VaultGraph {
        try ObsidianVaultCodec.decode(ObsidianVaultCodec.encode(graph))
    }

    private func corrupt(_ session: Session, with invalid: InvalidScalar) {
        switch invalid {
        case .negativeValue: session.value = -1
        case .nonfiniteValue: session.value = .infinity
        case .reversedDates: session.endedAt = instant.addingTimeInterval(-1)
        case .futureStart:
            session.startedAt = Date.now.addingTimeInterval(86400)
            session.endedAt = nil
        case .futureEnd: session.endedAt = Date.now.addingTimeInterval(86400)
        case .zeroCountdown: session.countdownDuration = 0
        case .negativeCountdown: session.countdownDuration = -1
        case .nonfiniteCountdown: session.countdownDuration = .infinity
        }
    }
}
