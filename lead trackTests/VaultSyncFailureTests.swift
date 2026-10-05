import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultSyncFailureTests {
    private let instant = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func ownerlessLocalSessionFailsBeforePublication() async throws {
        let local = VaultTestLocalStore()
        let session = Session(startedAt: instant, endedAt: instant, value: 7)
        local.models = VaultModels(sessions: [session])
        let remote = VaultTestRemote()
        let persistence = VaultTestState()
        let failure = try await failure(from: makeEngine(local, remote, persistence))
        expectOwnershipFailure(failure, stage: .localSnapshot, session: session)
        #expect(local.models.sessions.first === session)
        #expect(session.metric == nil)
        #expect(session.project == nil)
        #expect(session.value == 7)
        #expect(session.startedAt == instant)
        #expect(try await remote.graph().records.isEmpty)
        #expect(persistence.state == nil)
    }

    @Test
    func danglingRemoteRelationshipFailsBeforePublication() async throws {
        let incoming = sessionStore()
        var graph = try incoming.snapshot()
        let sessionID = try #require(incoming.models.sessions.first?.stableID)
        graph.records[sessionID]?.fields["metric"] = VaultModelLinks.linkID(UUID())
        let local = VaultTestLocalStore()
        let original = try local.snapshot()
        let remote = VaultTestRemote()
        try await remote.replaceGraph(graph)
        let before = try await remote.graph()
        let persistence = VaultTestState()
        let failure = try await failure(from: makeEngine(local, remote, persistence))
        expectInvalidFailure(failure, stage: .syncSnapshot)
        #expect(try local.snapshot() == original)
        #expect(try await remote.graph() == before)
        #expect(persistence.state == nil)
    }

    @Test
    func ownershipLostDuringCommitRetainsPublishedRecovery() async throws {
        let local = sessionStore()
        let session = try #require(local.models.sessions.first)
        let metric = try #require(session.metric)
        let remote = VaultTestRemote()
        let persistence = VaultTestState()
        await remote.beforeNextCommit {
            await MainActor.run { session.metric = nil }
        }
        let initial = try await failure(from: makeEngine(local, remote, persistence))
        expectOwnershipFailure(initial, stage: .localRecheck, session: session)
        let pending = try #require(persistence.state?.pending)
        #expect(pending.published)
        #expect(persistence.state?.baseline.records.isEmpty == true)
        let published = try await remote.graph()
        let sessionID = try #require(session.stableID)
        #expect(published.records[sessionID]?.fields["metric"] == VaultModelLinks.linkID(metric.stableID))
        let recovered = try await failure(from: makeEngine(local, remote, persistence))
        expectOwnershipFailure(recovered, stage: .localRecheck, session: session)
        #expect(persistence.state?.pending?.transactionID == pending.transactionID)
        #expect(local.models.sessions.first === session)
        #expect(session.metric == nil)
        #expect(session.value == 7)
        session.metric = metric
        _ = try await makeEngine(local, remote, persistence).synchronize()
        #expect(persistence.state?.pending == nil)
        #expect(try await remote.graph() == published)
    }

    @Test
    func healthCapabilityRejectionRetainsPublishedLocalApply() async throws {
        let local = VaultTestLocalStore()
        let metric = Metric(name: "Workouts", measurementType: .duration, healthSource: .workoutMinutes)
        local.models = VaultModels(metrics: [metric])
        let remote = VaultTestRemote()
        let persistence = VaultTestState()
        _ = try await makeEngine(local, remote, persistence).synchronize()
        let original = try local.snapshot()
        let id = try #require(metric.stableID)
        var graph = try await remote.graph()
        graph.records[id]?.fields["measurement_type"] = MeasurementType.count.vaultValue
        try await remote.replaceGraph(graph)
        let published = try await remote.graph()
        let failure = try await failure(from: makeEngine(local, remote, persistence))
        expectInvalidFailure(failure, stage: .localApply)
        let pending = try #require(persistence.state?.pending)
        #expect(pending.published)
        let destination = try #require(persistence.state?.destination)
        #expect(try local.appliedTransaction(destination: destination) != pending.transactionID)
        #expect(local.models.metrics.first === metric)
        #expect(metric.healthSource == .workoutMinutes)
        #expect(try local.snapshot() == original)
        metric.healthSourceRaw = nil
        _ = try await makeEngine(local, remote, persistence).synchronize()
        #expect(metric.measurementType == .count)
        #expect(persistence.state?.pending == nil)
        #expect(try await remote.graph() == published)
    }

    @Test
    func cancellationAfterCommitKeepsPublishedJournal() async throws {
        let local = VaultTestLocalStore()
        let original = try local.snapshot()
        let remote = VaultTestRemote()
        let persistence = VaultTestState()
        await remote.beforeNextCommit {
            withUnsafeCurrentTask { $0?.cancel() }
        }
        let engine = try makeEngine(local, remote, persistence)
        let task = Task { try await engine.synchronize() }
        await #expect(throws: CancellationError.self) { _ = try await task.value }
        let pending = try #require(persistence.state?.pending)
        #expect(pending.published)
        #expect(try local.snapshot() == original)
        #expect(try await remote.graph().records == pending.target.records)
        _ = try await makeEngine(local, remote, persistence).synchronize()
        #expect(persistence.state?.pending == nil)
    }

    private func sessionStore() -> VaultTestLocalStore {
        let metric = Metric(name: "Pages", measurementType: .count, createdAt: instant)
        let session = Session(metric: metric, startedAt: instant, endedAt: instant, value: 7)
        let local = VaultTestLocalStore()
        local.models = VaultModels(metrics: [metric], sessions: [session])
        return local
    }

    private func failure(from engine: VaultSyncEngine) async throws -> VaultSyncFailure {
        var failure: VaultSyncFailure?
        do {
            _ = try await engine.synchronize()
        } catch {
            failure = try #require(error as? VaultSyncFailure)
        }
        return try #require(failure)
    }

    private func expectInvalidFailure(_ failure: VaultSyncFailure, stage: VaultSyncFailure.Stage) {
        #expect(failure.stage == stage)
        guard case .invalid = failure.underlying else {
            Issue.record("Expected the original model validation error")
            return
        }
    }

    private func expectOwnershipFailure(
        _ failure: VaultSyncFailure, stage: VaultSyncFailure.Stage, session: Session
    ) {
        #expect(failure.stage == stage)
        guard case let .sessionWithoutMetric(issue) = failure.underlying else {
            Issue.record("Expected the structured session ownership error")
            return
        }
        #expect(issue.sessionID == session.stableID)
    }
}
