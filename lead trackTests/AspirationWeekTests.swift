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
    private let m: ModelFixture

    init() throws {
        m = try ModelFixture()
    }

    // MARK: - Fixtures (thin wrappers over the shared ModelFixture)

    private var calendar: Calendar {
        m.calendar
    }

    private func day(_ daysAgo: Int) -> Date {
        m.day(daysAgo)
    }

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        m.makeAspiration(title)
    }

    private func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        unit: String? = nil
    ) -> Metric {
        m.makeMetric(name: name, type: type, unit: unit)
    }

    private func makeProject(_ name: String, of metric: Metric) -> Project {
        m.makeProject(name, of: metric)
    }

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        m.addDuration(seconds, to: metric, project: project, at: start)
    }

    private func addCount(
        _ value: Double,
        to metric: Metric,
        project: Project? = nil,
        at start: Date
    ) {
        m.addCount(value, to: metric, project: project, at: start)
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
