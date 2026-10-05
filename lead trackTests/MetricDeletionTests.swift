#if canImport(SwiftData)
import Foundation
import SwiftData
import Testing
@testable import lead_track

/// Native SwiftData coverage only: the portable plain-class overlay cannot
/// demonstrate cascade or nullify behavior. Fixtures set only forward links;
/// inverse arrays are never backfilled or cleared (clearing can nullify owners).
struct MetricDeletionTests {
    private let fixture: ModelFixture
    private var context: ModelContext {
        fixture.context
    }

    init() throws {
        fixture = try ModelFixture()
    }

    @Test(arguments: [false, true])
    func metricDeletionIncludesDirectAndProjectOnlySessions(saveFirst: Bool) throws {
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("Book", of: metric)
        let emptyProject = fixture.makeProject("Empty", of: metric)
        let direct = insertSession(metric: metric)
        let both = insertSession(metric: metric, project: project)
        let projectOnly = insertSession(project: project)
        if saveFirst { try context.save() }

        // Exercise both pending and saved native relationships, including empty
        // or sparse inverse arrays on runtimes that leave them unpopulated.
        #expect(project.metric === metric)
        #expect(direct.metric === metric)
        #expect(both.project === project)
        #expect(projectOnly.metric == nil)
        #expect(projectOnly.project === project)
        #expect(emptyProject.metric === metric)
        try context.deleteMetricAndDependents(metric)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Session>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Project>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Metric>()).isEmpty)
    }

    @Test
    func metricDeletionPreservesUnassignedAndUnrelatedRecords() throws {
        let metric = fixture.makeMetric()
        let removedProject = fixture.makeProject("Removed", of: metric)
        _ = insertSession(project: removedProject)
        let otherMetric = fixture.makeMetric(name: "Other")
        let otherProject = fixture.makeProject("Other project", of: otherMetric)
        let ownerlessProject = Project(name: "Historical project")
        context.insert(ownerlessProject)
        let unassigned = insertSession()
        let unrelated = insertSession(metric: otherMetric, project: otherProject)
        let historical = insertSession(project: ownerlessProject)
        let expectedSessions = [unassigned.stableID, unrelated.stableID, historical.stableID]
        let expectedProjects = [otherProject.stableID, ownerlessProject.stableID]
        try context.save()

        try context.deleteMetricAndDependents(metric)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        let projects = try context.fetch(FetchDescriptor<Project>())
        #expect(Set(sessions.map(\.stableID)) == Set(expectedSessions))
        #expect(Set(projects.map(\.stableID)) == Set(expectedProjects))
        #expect(try context.fetch(FetchDescriptor<Metric>()).map(\.stableID) == [otherMetric.stableID])
        #expect(unassigned.metric == nil && unassigned.project == nil)
        #expect(historical.project === ownerlessProject)
    }

    @Test(arguments: [false, true])
    func projectDeletionRemovesOnlyForwardLinkedSessions(saveFirst: Bool) throws {
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("Removed", of: metric)
        let sibling = fixture.makeProject("Kept", of: metric)
        _ = insertSession(metric: metric, project: project)
        let projectOnly = insertSession(project: project)
        let directOnly = insertSession(metric: metric)
        let siblingSession = insertSession(metric: metric, project: sibling)
        let unassigned = insertSession()
        let expected = [directOnly.stableID, siblingSession.stableID, unassigned.stableID]
        if saveFirst { try context.save() }

        #expect(projectOnly.metric == nil && projectOnly.project === project)
        try context.deleteProjectAndDependents(project)
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<Session>())
        #expect(Set(sessions.map(\.stableID)) == Set(expected))
        #expect(try context.fetch(FetchDescriptor<Project>()).map(\.stableID) == [sibling.stableID])
        #expect(try context.fetch(FetchDescriptor<Metric>()).map(\.stableID) == [metric.stableID])
        #expect(siblingSession.project === sibling)
        #expect(directOnly.metric === metric)
        #expect(unassigned.metric == nil && unassigned.project == nil)
    }

    @Test(arguments: [false, true])
    func deletionRetainsNullifiedHistoricalModels(deleteMetric: Bool) throws {
        let metric = fixture.makeMetric()
        let project = fixture.makeProject("Book", of: metric)
        let aspiration = fixture.makeAspiration()
        let moment = Moment(text: "Kept history", aspiration: aspiration, metric: metric, project: project)
        let intention = try Intention.make(
            title: "Read", kind: .derived, aspiration: aspiration,
            derivedMode: .sessionCount, metric: metric, target: 3
        )
        context.insert(moment)
        context.insert(intention)
        _ = insertSession(metric: metric, project: project)
        try context.save()

        if deleteMetric {
            try context.deleteMetricAndDependents(metric)
        } else {
            try context.deleteProjectAndDependents(project)
        }
        try context.save()

        #expect(try context.fetch(FetchDescriptor<Moment>()).map(\.stableID) == [moment.stableID])
        #expect(try context.fetch(FetchDescriptor<Intention>()).map(\.stableID) == [intention.stableID])
        #expect(try context.fetch(FetchDescriptor<Aspiration>()).map(\.stableID) == [aspiration.stableID])
        #expect(moment.project == nil)
        #expect(moment.text == "Kept history")
        #expect(deleteMetric ? moment.metric == nil : moment.metric === metric)
        #expect(deleteMetric ? intention.metric == nil : intention.metric === metric)
    }

    private func insertSession(metric: Metric? = nil, project: Project? = nil) -> Session {
        let start = fixture.day(1)
        let session = Session(metric: metric, project: project, startedAt: start, endedAt: start.addingTimeInterval(60))
        context.insert(session)
        return session
    }
}
#endif
