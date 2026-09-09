import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct RetrospectiveReaderTests {
    private let start = Date(timeIntervalSince1970: 1_750_000_000)
    private var period: DateInterval {
        DateInterval(start: start, duration: 7 * 86400)
    }

    @Test
    func narrativeOnlyPeriodsUseHalfOpenEventAndWeekDates() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        let first = fixture.moment(under: aspiration, at: start)
        _ = fixture.moment(under: aspiration, at: period.end)
        let intention = fixture.intention(under: aspiration, week: start)
        _ = fixture.intention(under: aspiration, week: period.end)
        let note = fixture.note(under: aspiration, week: start)
        _ = fixture.note(under: aspiration, week: period.end)
        let snapshot = RetrospectiveReader.read(history: fixture.history, period: period)
        #expect(snapshot.moments.map(\.stableID) == [first.stableID])
        #expect(snapshot.intentions.map(\.stableID) == [intention.stableID])
        #expect(snapshot.checkIns.map(\.stableID) == [note.stableID])
        #expect(snapshot.effort.isEmpty)
        #expect(!snapshot.isEmpty)
    }

    @Test
    func closureInPeriodKeepsEarlierIntentionNarrativeReachable() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        let closed = fixture.intention(under: aspiration, week: start.addingTimeInterval(-7 * 86400))
        closed.close(outcome: .partly, at: start)
        let later = fixture.intention(under: aspiration, week: start.addingTimeInterval(-7 * 86400))
        later.close(outcome: .done, at: period.end)
        let snapshot = RetrospectiveReader.read(history: fixture.history, period: period)
        #expect(snapshot.intentions.map(\.stableID) == [closed.stableID])
    }

    @Test
    func principleFilterDoesNotAttributeUntaggedEffortOrNotes() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        let principle = Principle(text: "Pages before feeds", aspiration: aspiration)
        let kept = fixture.moment(under: aspiration, at: start)
        kept.principle = principle
        _ = fixture.moment(under: aspiration, at: start)
        let intention = fixture.intention(under: aspiration, week: start)
        intention.principle = principle
        _ = fixture.intention(under: aspiration, week: start)
        _ = fixture.note(under: aspiration, week: start)
        _ = fixture.session(metric: fixture.metric(), at: start, value: 5)
        let snapshot = RetrospectiveReader.read(
            history: fixture.history, period: period, filter: RetrospectiveFilter(principle: principle)
        )
        #expect(snapshot.moments.map(\.stableID) == [kept.stableID])
        #expect(snapshot.intentions.map(\.stableID) == [intention.stableID])
        #expect(snapshot.effort.isEmpty)
        #expect(snapshot.checkIns.isEmpty)
    }

    @Test
    func projectFilterRequiresActualProjectLinks() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        let metric = fixture.metric()
        let project = Project(name: "Chapter", metric: metric)
        fixture.add(project)
        let kept = fixture.moment(under: aspiration, at: start)
        kept.project = project
        _ = fixture.moment(under: aspiration, at: start)
        let linked = fixture.session(metric: metric, at: start, value: 7)
        linked.project = project
        project.sessions = [linked]
        _ = fixture.session(metric: metric, at: start, value: 11)
        _ = fixture.intention(under: aspiration, week: start)
        _ = fixture.note(under: aspiration, week: start)
        let snapshot = RetrospectiveReader.read(
            history: fixture.history, period: period, filter: RetrospectiveFilter(project: project)
        )
        #expect(snapshot.moments.map(\.stableID) == [kept.stableID])
        #expect(snapshot.effort.map(\.total) == [7])
        #expect(snapshot.intentions.isEmpty)
        #expect(snapshot.checkIns.isEmpty)
    }

    @Test
    func archivedHistoryDeduplicatesMetricAndProjectAttachments() throws {
        let fixture = try RetrospectiveFixture()
        let aspiration = fixture.aspiration()
        aspiration.archive(at: start)
        let unrelated = fixture.aspiration()
        _ = fixture.moment(under: unrelated, at: start)
        let kept = fixture.moment(under: aspiration, at: start)
        let metric = fixture.metric()
        metric.archivedAt = start
        let project = Project(name: "Chapter", metric: metric)
        fixture.add(project)
        let session = fixture.session(metric: metric, at: start, value: 7)
        session.project = project
        project.sessions = [session]
        aspiration.metrics = [metric]
        aspiration.projects = [project]
        let snapshot = RetrospectiveReader.read(
            history: fixture.history, period: period, filter: RetrospectiveFilter(aspiration: aspiration)
        )
        #expect(snapshot.moments.map(\.stableID) == [kept.stableID])
        #expect(snapshot.effort.map(\.total) == [7])
        let all = RetrospectiveReader.read(history: fixture.history, period: period)
        #expect(all.effort.map(\.total) == [7])
    }

    @Test
    func effortKeepsMetricUnitsAndExcludesRunningAndEndBoundarySessions() throws {
        let fixture = try RetrospectiveFixture()
        let pages = fixture.metric()
        let distance = fixture.metric(name: "Walking", unit: "km")
        let timer = fixture.metric(name: "Reading", type: .duration)
        _ = fixture.session(metric: pages, at: start, value: 7)
        _ = fixture.session(metric: distance, at: start, value: 2.5)
        let timed = Session(metric: timer, startedAt: start, endedAt: start.addingTimeInterval(300))
        fixture.add(timed)
        let running = Session(metric: timer, startedAt: start)
        fixture.add(running)
        timer.sessions = [timed, running]
        _ = fixture.session(metric: pages, at: period.end, value: 99)
        let snapshot = RetrospectiveReader.read(history: fixture.history, period: period)
        #expect(snapshot.effort.first { $0.metric === pages }?.total == 7)
        #expect(snapshot.effort.first { $0.metric === distance }?.total == 2.5)
        #expect(snapshot.effort.first { $0.metric === timer }?.total == 300)
    }
}

/// Shared fixtures explicitly maintain inverses on Linux's plain models.
final class RetrospectiveFixture {
    var history = RetrospectiveHistory(aspirations: [], metrics: [])
    #if canImport(SwiftData)
    private let context: ModelContext
    #endif

    init() throws {
        #if canImport(SwiftData)
        context = try ModelContext(SharedModelContainer.create(inMemoryOnly: true))
        #endif
    }

    func aspiration() -> Aspiration {
        let aspiration = Aspiration(title: "Grow wiser")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        history.aspirations.append(aspiration)
        return aspiration
    }

    func moment(under aspiration: Aspiration, at date: Date) -> Moment {
        let moment = Moment(text: "A conversation I want to remember", aspiration: aspiration, occurredAt: date)
        #if canImport(SwiftData)
        context.insert(moment)
        #endif
        if !aspiration.moments.contains(where: { $0 === moment }) { aspiration.moments.append(moment) }
        return moment
    }

    func intention(under aspiration: Aspiration, week: Date) -> Intention {
        let intention = Intention(title: "Listen closely", kind: .reflective, aspiration: aspiration, weekStart: week)
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        if !aspiration.intentions.contains(where: { $0 === intention }) { aspiration.intentions.append(intention) }
        return intention
    }

    func note(under aspiration: Aspiration, week: Date) -> AspirationCheckIn {
        let note = AspirationCheckIn(aspiration: aspiration, rating: .unsure, weekStart: week, note: "Less rushing")
        #if canImport(SwiftData)
        context.insert(note)
        #endif
        if !aspiration.checkIns.contains(where: { $0 === note }) { aspiration.checkIns.append(note) }
        return note
    }

    func metric(name: String = "Books", type: MeasurementType = .count, unit: String = "pages") -> Metric {
        let metric = Metric(name: name, measurementType: type, unit: unit)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        history.metrics.append(metric)
        return metric
    }

    func session(metric: Metric, at date: Date, value: Double) -> Session {
        let session = Session(metric: metric, startedAt: date, value: value)
        add(session)
        if !metric.sessions.contains(where: { $0 === session }) { metric.sessions.append(session) }
        return session
    }

    func add(_ session: Session) {
        #if canImport(SwiftData)
        context.insert(session)
        #endif
    }

    func add(_ project: Project) {
        #if canImport(SwiftData)
        context.insert(project)
        #endif
        history.projects.append(project)
    }
}
