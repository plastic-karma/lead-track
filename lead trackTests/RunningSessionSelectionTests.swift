import Foundation
import Testing
@testable import lead_track

struct RunningSessionSelectionTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)

    @Test
    func projectOwnedTimerIsSelectedUntilStopped() {
        let metric = Metric(name: "Reading")
        let project = Project(name: "Book", metric: metric)
        let session = Session(project: project, startedAt: start)
        let completed = Session(metric: metric, startedAt: start, endedAt: start)
        let counted = Session(metric: metric, startedAt: start, value: 1)
        let sessions = [completed, counted, session]

        #expect(SessionCollection.runningSession(for: metric, in: sessions) === session)
        session.endedAt = start.addingTimeInterval(60)
        #expect(SessionCollection.runningSession(for: metric, in: sessions) == nil)
        #expect(session.metric == nil && session.project === project)
    }

    @Test
    func stableIdentityMatchesAcrossModelInstances() {
        let configured = Metric(name: "Reading")
        let fetched = Metric(name: "Renamed")
        fetched.stableID = configured.stableID
        let unrelated = Session(metric: Metric(name: "Reading"), startedAt: start)
        let session = Session(metric: fetched, startedAt: start)

        #expect(SessionCollection.runningSession(for: configured, in: [unrelated, session]) === session)
    }

    @Test
    func missingIDsDoNotMatchUnrelatedMetrics() {
        let metric = Metric(name: "Reading")
        let other = Metric(name: "Reading")
        metric.stableID = nil
        other.stableID = nil
        let unrelated = Session(metric: other, startedAt: start)
        let owned = Session(metric: metric, startedAt: start)

        #expect(SessionCollection.runningSession(for: metric, in: [unrelated]) == nil)
        #expect(SessionCollection.runningSession(for: metric, in: [unrelated, owned]) === owned)
    }

    @Test
    func directOwnershipTakesPrecedenceOverConflictingProject() {
        let metric = Metric(name: "Reading")
        let other = Metric(name: "Exercise")
        let project = Project(name: "Book", metric: metric)
        let session = Session(metric: other, project: project, startedAt: start)

        #expect(SessionCollection.runningSession(for: metric, in: [session]) == nil)
        #expect(SessionCollection.runningSession(for: other, in: [session]) === session)
    }

    @Test
    func unassignedTimerDoesNotHideLiveActivityForOwnedTimer() {
        let unassigned = Session(startedAt: start)
        let metric = Metric(name: "Reading")
        let project = Project(name: "Book", metric: metric)
        let completed = Session(metric: metric, startedAt: start, endedAt: start)
        let owned = Session(project: project, startedAt: start)

        #expect(SessionCollection.runningSession(in: [unassigned, completed, owned]) === owned)
        #expect(SessionCollection.runningSession(in: [unassigned, completed]) == nil)
        #expect(SessionCollection.runningSession(for: metric, in: [unassigned]) == nil)
        #expect(unassigned.isRunning && unassigned.metric == nil && unassigned.project == nil)
    }
}
