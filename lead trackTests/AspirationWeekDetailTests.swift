import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The drill-in behind an aspiration's review card: the week is built
/// unconditionally (a quiet week still renders), the sources split the
/// window's effort per attachment under the same de-dup as the totals, and
/// the frame anchors the day labels.
struct AspirationWeekDetailTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        unit: String? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type, unit: unit)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeProject(_ name: String, of metric: Metric) -> Project {
        let project = Project(name: name, metric: metric)
        #if canImport(SwiftData)
        context.insert(project)
        #else
        metric.projects.append(project)
        #endif
        return project
    }

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        let session = Session(
            metric: metric, project: project,
            startedAt: start, endedAt: start.addingTimeInterval(seconds)
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        project?.sessions.append(session)
        #endif
    }

    private func addCount(_ value: Double, to metric: Metric, at start: Date) {
        let session = Session(metric: metric, startedAt: start, value: value)
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func attach(_ metric: Metric, to aspiration: Aspiration) {
        aspiration.metrics.append(metric)
    }
}

// MARK: - The week and its sources

extension AspirationWeekDetailTests {
    @Test
    func detailSplitsTheWeekBySource() {
        let aspiration = makeAspiration()
        let reading = makeMetric(name: "Reading", type: .duration)
        addDuration(3600, to: reading, at: day(1))
        let pages = makeMetric(name: "Pages", type: .count, unit: "pages")
        addCount(40, to: pages, at: day(2))
        attach(reading, to: aspiration)
        attach(pages, to: aspiration)

        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration)

        #expect(detail.week.totals.map(\.text) == ["1h 00m", "40 pages"])
        #expect(detail.sources.map(\.name) == ["Reading", "Pages"])
        #expect(detail.sources.map(\.text) == ["1h 00m", "40 pages"])
    }

    @Test
    func quietWeekStillBuilds() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(7200, to: metric, at: day(40))
        attach(metric, to: aspiration)

        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration)

        #expect(detail.week.totals.isEmpty)
        #expect(detail.sources.isEmpty)
        #expect(detail.busiestDayOffset == nil)
    }

    @Test
    func detailWindowsToTheRequestedWeek() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .count, unit: "pages")
        addCount(10, to: metric, at: day(2))
        addCount(5, to: metric, at: day(9))
        attach(metric, to: aspiration)

        let thisWeek = WeeklyReview.aspirationWeekDetail(for: aspiration)
        #expect(thisWeek.week.totals.map(\.text) == ["10 pages"])

        let lastWeek = WeeklyReview.aspirationWeekDetail(for: aspiration, weeksBack: 1)
        #expect(lastWeek.week.totals.map(\.text) == ["5 pages"])
        #expect(lastWeek.sources.map(\.text) == ["5 pages"])
    }

    @Test
    func sourcesDoNotDoubleCountAProjectInsideItsMetric() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, project: project, at: day(2))
        attach(metric, to: aspiration)
        aspiration.projects.append(project)

        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration)

        #expect(detail.sources.count == 1)
        #expect(detail.sources.first?.text == "20m 00s")
    }
}

// MARK: - The distribution frame

extension AspirationWeekDetailTests {
    @Test
    func busiestDayIsTheOneWithTheMostSessions() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(600, to: metric, at: day(6))
        addDuration(600, to: metric, at: day(0))
        addDuration(600, to: metric, at: day(0))
        attach(metric, to: aspiration)

        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration)

        #expect(detail.week.dailySeries == [1, 0, 0, 0, 0, 0, 2])
        #expect(detail.busiestDayOffset == 6)
        #expect(detail.day(at: 6, calendar: calendar) == day(0))
    }

    @Test
    func detailIntentionLinesStayEmpty() throws {
        let aspiration = makeAspiration()
        let intention = try Intention.make(
            title: "3 walks", kind: .counted, aspiration: aspiration,
            target: 3, calendar: calendar
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        _ = intention

        let detail = WeeklyReview.aspirationWeekDetail(for: aspiration)

        #expect(detail.week.intentions.isEmpty)
    }
}
