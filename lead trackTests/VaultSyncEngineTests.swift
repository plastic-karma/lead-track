import Foundation
import Testing
@testable import lead_track

@MainActor
struct VaultSyncEngineTests {
    @Test
    func obsidianDescriptionRenameAndMetadataSurviveLaterAppEdits() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        let engine = try makeEngine(local, remote, persistence)
        _ = try await engine.synchronize()
        var graph = try await remote.graph()
        let id = try #require(local.models.aspirations.first?.stableID)
        graph.records[id]?.body = "Description written in Obsidian.\n\n"
        graph.records[id]?.path = "Aspirations/My renamed note.md"
        graph.records[id]?.fields["custom"] = .raw("\n  color: copper\n")
        graph.records[id]?.propertyOrder.append("custom")
        try await remote.replaceGraph(graph)
        _ = try await engine.synchronize()
        #expect(local.models.aspirations.first?.detail == "Description written in Obsidian.\n\n")
        local.models.aspirations.first?.title = "Changed in LeadStone"
        _ = try await engine.synchronize()
        let uploaded = try await remote.graph()
        #expect(uploaded.records[id]?.path == "Aspirations/My renamed note.md")
        #expect(uploaded.records[id]?.body == graph.records[id]?.body)
        #expect(uploaded.records[id]?.fields["custom"] == graph.records[id]?.fields["custom"])
        #expect(uploaded.records[id]?.fields["title"] == .string("Changed in LeadStone"))
    }

    @Test
    func localEditDuringPushIsPreservedAndStillNeedsPublication() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        await remote.beforeNextCommit {
            await MainActor.run { local.models.aspirations.first?.detail = "Typed while GitHub was responding" }
        }
        let result = try await makeEngine(local, remote, persistence).synchronize()
        #expect(result.needsSync)
        #expect(local.models.aspirations.first?.detail == "Typed while GitHub was responding")
        _ = try await makeEngine(local, remote, persistence).synchronize()
        let uploaded = try await remote.graph()
        #expect(uploaded.records.values.first?.body == "Typed while GitHub was responding")
    }

    @Test
    func successfulPushWithLostAcknowledgmentRecoversAfterRestart() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        await remote.loseNextAcknowledgment()
        await #expect(throws: URLError.self) {
            _ = try await makeEngine(local, remote, persistence).synchronize()
        }
        local.models.aspirations.first?.detail = "A later offline edit"
        let restarted = try makeEngine(local, remote, persistence)
        let recovery = try await restarted.synchronize()
        #expect(recovery.conflicts.isEmpty)
        #expect(recovery.needsSync)
        _ = try await restarted.synchronize()
        let uploaded = try await remote.graph()
        #expect(uploaded.records.values.first?.body == "A later offline edit")
        #expect(persistence.state?.pending == nil)
    }

    @Test
    func strippingTrackedFrontmatterIsNotADeletion() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        let engine = try makeEngine(local, remote, persistence)
        _ = try await engine.synchronize()
        let graph = try await remote.graph()
        let record = try #require(graph.records.values.first)
        await remote.replaceFile(record.path, data: Data("---\ntitle: Missing identity\n---\nNew text\n".utf8))
        await #expect(throws: (any Error).self) { _ = try await engine.synchronize() }
        #expect(local.models.aspirations.first?.detail == "Original description")
    }

    @Test
    func receiptPreventsReplayingAnAlreadyAppliedRemoteEdit() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        let engine = try makeEngine(local, remote, persistence)
        _ = try await engine.synchronize()
        var graph = try await remote.graph()
        let id = try #require(local.models.aspirations.first?.stableID)
        graph.records[id]?.body = "Applied remote description"
        try await remote.replaceGraph(graph)
        persistence.failAcknowledgment = true
        await #expect(throws: URLError.self) { _ = try await engine.synchronize() }
        #expect(local.models.aspirations.first?.detail == "Applied remote description")
        local.models.aspirations.first?.detail = "Original description"
        let restarted = try makeEngine(local, remote, persistence)
        _ = try await restarted.synchronize()
        #expect(local.models.aspirations.first?.detail == "Original description")
        _ = try await restarted.synchronize()
        #expect(try await remote.graph().records[id]?.body == "Original description")
    }

    @Test
    func lostAcknowledgmentFollowedByRemoteDeletionCannotResurrectSilently() async throws {
        let local = VaultTestLocalStore()
        let persistence = VaultTestState()
        let remote = VaultTestRemote()
        await remote.loseNextAcknowledgment()
        await #expect(throws: URLError.self) {
            _ = try await makeEngine(local, remote, persistence).synchronize()
        }
        try await remote.replaceGraph(VaultGraph())
        let restarted = try makeEngine(local, remote, persistence)
        let result = try await restarted.synchronize()
        let conflict = try #require(result.conflicts.first)
        #expect(conflict.remote == nil)
        #expect(try await remote.graph().records.isEmpty)
        _ = try await restarted.synchronize(
            resolutions: [conflict.id: VaultResolution(conflict: conflict, choice: .remote)]
        )
        #expect(local.models.aspirations.isEmpty)
        #expect(try await remote.graph().records.isEmpty)
    }

    @Test
    func projectOwnedSessionRoundTripsThroughSyncWithoutDataLoss() async throws {
        let date = Date(timeIntervalSince1970: 1_750_000_000)
        let metric = Metric(name: "Reading", measurementType: .count, createdAt: date)
        let project = Project(name: "Book", metric: metric, startedAt: date)
        let session = Session(project: project, startedAt: date, endedAt: date, value: 7)
        let local = VaultTestLocalStore()
        local.models = VaultModels(metrics: [metric], projects: [project], sessions: [session])
        let remote = VaultTestRemote()
        let engine = try makeEngine(local, remote, VaultTestState())
        let metricID = try #require(metric.stableID)
        let projectID = try #require(project.stableID)
        let sessionID = try #require(session.stableID)
        _ = try await engine.synchronize()
        var uploaded = try await remote.graph()
        let restored = try VaultModelCodec.materialize(uploaded)
        let uploadedSession = try #require(restored.sessions.first)
        #expect(Set(uploaded.records.keys) == [metricID, projectID, sessionID])
        #expect(uploadedSession.metric?.stableID == metricID)
        #expect(uploadedSession.project?.stableID == projectID)
        #expect(uploadedSession.startedAt == date)
        #expect(uploadedSession.value == 7)
        uploaded.records[sessionID]?.fields["value"] = .number(9)
        try await remote.replaceGraph(uploaded)
        _ = try await engine.synchronize()
        #expect(local.models.sessions.first === session)
        #expect(session.value == 9)
        #expect(session.project?.stableID == projectID)
        #expect(session.startedAt == date)
    }
}
