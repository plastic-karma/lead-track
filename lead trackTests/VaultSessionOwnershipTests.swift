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

    @Test
    func orphanDiagnosticPreservesItsIdentityAndData() throws {
        let session = Session(startedAt: instant, endedAt: instant.addingTimeInterval(60), value: 7)
        session.stableID = fixtureID(1)
        let models = VaultModels(sessions: [session])
        let issue = try ownershipIssue(models)
        #expect(issue == VaultSessionOwnershipIssue(
            sessionID: fixtureID(1), projectID: nil, metricBacklinkIDs: [], projectBacklinkIDs: []
        ))
        #expect(models.sessions.count == 1)
        #expect(models.sessions.first === session)
        #expect(session.stableID == fixtureID(1))
        #expect(session.metric == nil)
        #expect(session.project == nil)
        #expect(session.startedAt == instant)
        #expect(session.endedAt == instant.addingTimeInterval(60))
        #expect(session.value == 7)
    }

    #if !canImport(SwiftData) // These fixtures require broken inverse relationships.
    @Test
    func backlinkDiagnosticsUseSessionIdentityNotSharedProject() throws {
        let models = backlinkModels()
        let session = try #require(models.sessions.first)
        let linkedProject = models.projects[0]
        let backlinkProject = models.projects[1]
        let metric = models.metrics[0]
        let unrelatedMetric = models.metrics[1]
        let matchingCopy = try #require(metric.sessions.first)
        let otherSession = try #require(unrelatedMetric.sessions.first)
        let issue = try ownershipIssue(models)
        #expect(issue == VaultSessionOwnershipIssue(
            sessionID: fixtureID(1), projectID: fixtureID(2),
            metricBacklinkIDs: [fixtureID(4)], projectBacklinkIDs: [fixtureID(2), fixtureID(6)]
        ))
        #expect(session.metric == nil)
        #expect(session.project === linkedProject)
        #expect(session.stableID == fixtureID(1))
        #expect(session.value == 7)
        #expect(metric.sessions.count == 1 && metric.sessions.first === matchingCopy)
        #expect(unrelatedMetric.sessions.count == 1 && unrelatedMetric.sessions.first === otherSession)
        #expect(backlinkProject.sessions.count == 1 && backlinkProject.sessions.first === matchingCopy)
        #expect(linkedProject.sessions.count == 2)
        #expect(linkedProject.sessions.contains { $0 === session })
        #expect(linkedProject.sessions.contains { $0 === otherSession })
    }

    private func backlinkModels() -> VaultModels {
        let linkedProject = Project(name: "Private linked project", startedAt: instant)
        linkedProject.stableID = fixtureID(2)
        let session = Session(project: linkedProject, startedAt: instant, endedAt: instant, value: 7)
        session.stableID = fixtureID(1)
        let matchingCopy = Session(startedAt: instant, endedAt: instant)
        matchingCopy.stableID = fixtureID(1)
        let otherSession = Session(project: linkedProject, startedAt: instant, endedAt: instant)
        otherSession.stableID = fixtureID(3)
        let metric = Metric(name: "Private metric", createdAt: instant)
        metric.stableID = fixtureID(4)
        metric.sessions = [matchingCopy]
        let unrelatedMetric = Metric(name: "Other private metric", createdAt: instant)
        unrelatedMetric.stableID = fixtureID(5)
        unrelatedMetric.sessions = [otherSession]
        let backlinkProject = Project(name: "Private backlink project", startedAt: instant)
        backlinkProject.stableID = fixtureID(6)
        backlinkProject.sessions = [matchingCopy]
        linkedProject.sessions = [session, otherSession]
        return VaultModels(
            metrics: [metric, unrelatedMetric], projects: [linkedProject, backlinkProject], sessions: [session]
        )
    }

    @Test(arguments: [false, true], [false, true])
    func brokenInverseDiagnosticsPreserveMissingOwners(includeActualSession: Bool, hasIdentity: Bool) throws {
        let session = Session(startedAt: instant, endedAt: instant)
        session.stableID = hasIdentity ? fixtureID(1) : nil
        let unrelated = Session(startedAt: instant, endedAt: instant)
        unrelated.stableID = nil
        let metric = Metric(name: "Private metric", createdAt: instant)
        metric.stableID = fixtureID(4)
        let project = Project(name: "Private project", startedAt: instant)
        project.stableID = fixtureID(2)
        metric.sessions = includeActualSession ? [unrelated, session] : [unrelated]
        project.sessions = metric.sessions
        let models = VaultModels(metrics: [metric], projects: [project], sessions: [session])
        let issue = try ownershipIssue(models)
        #expect(issue == VaultSessionOwnershipIssue(
            sessionID: hasIdentity ? fixtureID(1) : nil, projectID: nil,
            metricBacklinkIDs: includeActualSession ? [fixtureID(4)] : [],
            projectBacklinkIDs: includeActualSession ? [fixtureID(2)] : []
        ))
        #expect(session.stableID == (hasIdentity ? fixtureID(1) : nil))
        #expect(unrelated.stableID == nil)
        #expect(session.metric == nil && session.project == nil)
        #expect(metric.sessions.count == (includeActualSession ? 2 : 1))
        #expect(project.sessions.count == metric.sessions.count)
        #expect(metric.sessions.first === unrelated)
        #expect(project.sessions.first === unrelated)
    }
    #endif

    private func fixtureID(_ value: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, value))
    }

    private func ownershipIssue(_ models: VaultModels) throws -> VaultSessionOwnershipIssue {
        do {
            try VaultModelValidation.validate(models)
        } catch let VaultError.sessionWithoutMetric(issue) {
            return issue
        }
        Issue.record("Expected a missing session metric diagnostic")
        throw VaultError.invalid("Missing ownership diagnostic")
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
