import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The aspiration lens of the weekly review: windowed this-week breakdown,
/// de-dup, quiet handling, and earlier-week browsing. The review carries no
/// lifetime figures — those live on the aspiration's own screen.
struct AspirationWeekTests {
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
        register(
            Session(
                metric: metric, project: project,
                startedAt: start, endedAt: start.addingTimeInterval(seconds)
            ),
            metric: metric, project: project
        )
    }

    private func addCount(_ value: Double, to metric: Metric, at start: Date) {
        register(Session(metric: metric, startedAt: start, value: value), metric: metric)
    }

    private func register(_ session: Session, metric: Metric, project: Project? = nil) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        project?.sessions.append(session)
        #endif
    }

    private func attach(_ metric: Metric, to aspiration: Aspiration) {
        aspiration.metrics.append(metric)
    }
}

// MARK: - Backwards compatibility

extension AspirationWeekTests {
    @Test
    func noAspirationsLeavesTheMetricReviewUntouched() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(1))

        let review = WeeklyReview.build(metrics: [metric])

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.isEmpty)
        #expect(review.metricWeeks.count == 1)
    }
}

// MARK: - The week's window

extension AspirationWeekTests {
    @Test
    func activeAspirationBreaksThisWeekDownByUnit() {
        let aspiration = makeAspiration()
        let reading = makeMetric(name: "Reading", type: .duration)
        addDuration(3600, to: reading, at: day(1))
        let pages = makeMetric(name: "Pages", type: .count, unit: "pages")
        addCount(40, to: pages, at: day(2))
        attach(reading, to: aspiration)
        attach(pages, to: aspiration)

        let review = WeeklyReview.build(metrics: [reading, pages], aspirations: [aspiration])

        #expect(review.aspirationWeeks.count == 1)
        let week = review.aspirationWeeks[0]
        #expect(week.totals.map(\.text) == ["1h 00m", "40 pages"])
        #expect(week.sessionCount == 2)
        #expect(week.activeDays == 2)
    }

    @Test
    func weekTotalsExcludeEffortOutsideTheWindow() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(3600, to: metric, at: day(1))
        addDuration(7200, to: metric, at: day(40))
        attach(metric, to: aspiration)

        let week = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration]
        ).aspirationWeeks[0]

        #expect(week.totals.map(\.text) == ["1h 00m"])
        #expect(week.sessionCount == 1)
    }

    @Test
    func dailySeriesCountsSessionsPerDay() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(600, to: metric, at: day(6))
        addDuration(600, to: metric, at: day(0))
        addDuration(600, to: metric, at: day(0))
        attach(metric, to: aspiration)

        let week = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration]
        ).aspirationWeeks[0]

        #expect(week.dailySeries == [1, 0, 0, 0, 0, 0, 2])
    }
}

// MARK: - De-dup & quiet

extension AspirationWeekTests {
    @Test
    func weekDoesNotDoubleCountAProjectInsideItsMetric() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        let project = makeProject("Sapiens", of: metric)
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, project: project, at: day(2))
        attach(metric, to: aspiration)
        aspiration.projects.append(project)

        let week = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration]
        ).aspirationWeeks[0]

        #expect(week.totals.map(\.text) == ["20m 00s"])
        #expect(week.sessionCount == 2)
    }

    @Test
    func aspirationQuietThisWeekRestsInTheQuietList() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .duration)
        addDuration(7200, to: metric, at: day(40))
        attach(metric, to: aspiration)

        let review = WeeklyReview.build(metrics: [metric], aspirations: [aspiration])

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.count == 1)
        #expect(review.quietAspirations[0].title == "Grow wiser")
    }
}

// MARK: - Earlier weeks

extension AspirationWeekTests {
    @Test
    func earlierWeekWindowsToThatWeekNotToday() {
        let aspiration = makeAspiration()
        let metric = makeMetric(type: .count, unit: "pages")
        addCount(10, to: metric, at: day(2))
        addCount(5, to: metric, at: day(9))
        attach(metric, to: aspiration)

        let thisWeek = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration], weeksBack: 0
        ).aspirationWeeks[0]
        #expect(thisWeek.totals.map(\.text) == ["10 pages"])

        let lastWeek = WeeklyReview.build(
            metrics: [metric], aspirations: [aspiration], weeksBack: 1
        ).aspirationWeeks[0]
        #expect(lastWeek.totals.map(\.text) == ["5 pages"])
    }
}
