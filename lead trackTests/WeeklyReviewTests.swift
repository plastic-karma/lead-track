import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct WeeklyReviewTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    /// Relationship arrays only sync through a context on Apple platforms;
    /// the Linux overlay compiles the models as plain classes instead.
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    /// Midnight `daysAgo` days back — sessions placed at a day's first
    /// instant can never land after the builder's `now`.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
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

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        at start: Date
    ) {
        register(
            Session(
                metric: metric,
                startedAt: start,
                endedAt: start.addingTimeInterval(seconds)
            ),
            with: metric
        )
    }

    private func addCount(
        _ value: Double,
        to metric: Metric,
        at start: Date
    ) {
        register(
            Session(metric: metric, startedAt: start, value: value),
            with: metric
        )
    }

    private func register(_ session: Session, with metric: Metric) {
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    // MARK: - Active vs Quiet

    @Test
    func splitsActiveAndQuietMetrics() {
        let active = makeMetric(name: "Active")
        addDuration(600, to: active, at: day(1))
        let stale = makeMetric(name: "Stale")
        addDuration(600, to: stale, at: day(10))
        let silent = makeMetric(name: "Silent")

        let review = WeeklyReview.build(metrics: [active, stale, silent])

        #expect(review.metricWeeks.map(\.name) == ["Active"])
        #expect(review.quietMetrics.map(\.name) == ["Stale", "Silent"])
        #expect(review.quietMetrics.last?.icon == "clock")
        #expect(review.quietMetrics.last?.id == silent.stableID?.uuidString)
    }

    @Test
    func runningSessionsDoNotCount() {
        let metric = makeMetric()
        register(Session(metric: metric, startedAt: day(0)), with: metric)

        let review = WeeklyReview.build(metrics: [metric])

        #expect(review.metricWeeks.isEmpty)
        #expect(review.quietMetrics.count == 1)
    }

    // MARK: - Metric Week

    @Test
    func totalsAndIdentityCarryThrough() {
        let metric = makeMetric(name: "Pages", type: .count, unit: "pages")
        addCount(5, to: metric, at: day(1))
        addCount(3, to: metric, at: day(2))

        let week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]

        #expect(week.total == 8)
        #expect(week.sessionCount == 2)
        #expect(week.activeDays == 2)
        #expect(week.unit == "pages")
        #expect(week.measurementType == .count)
    }

    @Test
    func dailySeriesIsZeroFilledOldestFirst() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(6))
        addDuration(300, to: metric, at: day(0))

        let week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]

        #expect(week.dailySeries == [600, 0, 0, 0, 0, 0, 300])
    }

    @Test
    func goalDaysHitNeedsAGoal() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(1))
        addDuration(300, to: metric, at: day(2))

        var week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]
        #expect(week.goalDaysHit == nil)

        metric.dailyGoal = 600
        week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]
        #expect(week.goalDaysHit == 1)
    }

    @Test
    func streakRidesTheWeekNotTheInsightList() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(0))
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, at: day(2))

        let week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]

        #expect(week.streak == 3)
        #expect(week.insights.isEmpty)
    }

    @Test
    func insightsLeadWithDistribution() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, at: day(2))
        addDuration(600, to: metric, at: day(3))
        addDuration(600, to: metric, at: day(8))
        addDuration(600, to: metric, at: day(8))

        let insights = WeeklyReview.build(metrics: [metric])
            .metricWeeks[0].insights

        let weekday = Calendar.current.component(.weekday, from: day(1))
        #expect(insights == [
            .dayOfWeekMode(weekday: weekday, ratio: 0.5, sessionCount: 2),
            .volumeChange(
                measurementType: .duration, unit: nil,
                currentTotal: 2400, previousTotal: 1200,
                currentCount: 4, previousCount: 2
            ),
            .activeDaysChange(currentDays: 3, previousDays: 1)
        ])
    }

    // MARK: - Week-over-Week Change

    @Test
    func changeClassifiesUpDownFlatAndNoBaseline() {
        let up = makeMetric(name: "Up")
        addDuration(1200, to: up, at: day(1))
        addDuration(600, to: up, at: day(8))
        let down = makeMetric(name: "Down")
        addDuration(300, to: down, at: day(1))
        addDuration(600, to: down, at: day(8))
        let flat = makeMetric(name: "Flat")
        addDuration(600, to: flat, at: day(1))
        addDuration(600, to: flat, at: day(8))
        let fresh = makeMetric(name: "Fresh")
        addDuration(600, to: fresh, at: day(1))

        let changes = WeeklyReview.build(metrics: [up, down, flat, fresh])
            .metricWeeks.map(\.change)

        #expect(changes == [
            .up(ratio: 1.0), .down(ratio: -0.5), .flat, .noBaseline
        ])
    }

    @Test
    func previousWeekStopsAtThePeriodBoundary() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(1))
        addDuration(600, to: metric, at: day(14))

        let week = WeeklyReview.build(metrics: [metric]).metricWeeks[0]

        #expect(week.change == .noBaseline)
    }

    // MARK: - Earlier Weeks

    @Test
    func weeksBackShiftsThePeriod() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(8))
        addDuration(300, to: metric, at: day(1))

        let review = WeeklyReview.build(metrics: [metric], weeksBack: 1)

        #expect(review.start == day(13))
        #expect(review.end == day(7))
        #expect(review.metricWeeks[0].total == 600)
        #expect(review.metricWeeks[0].dailySeries[5] == 600)
    }

    @Test
    func weekBoundariesAreHalfOpen() {
        let metric = makeMetric()
        addDuration(600, to: metric, at: day(6))
        addDuration(300, to: metric, at: day(7))

        let current = WeeklyReview.build(metrics: [metric])
        let past = WeeklyReview.build(metrics: [metric], weeksBack: 1)

        #expect(current.metricWeeks[0].total == 600)
        #expect(past.metricWeeks[0].total == 300)
    }

    @Test
    func pastWeeksLeaveTheStreakToToday() {
        let metric = makeMetric()
        for daysAgo in 0 ... 9 {
            addDuration(600, to: metric, at: day(daysAgo))
        }

        let current = WeeklyReview.build(metrics: [metric])
        let past = WeeklyReview.build(metrics: [metric], weeksBack: 1)

        #expect(current.metricWeeks[0].streak == 10)
        #expect(past.metricWeeks[0].streak == 0)
    }

    // MARK: - Header Aggregates

    @Test
    func totalDurationLeavesCountsOut() {
        let timed = makeMetric(name: "Focus")
        addDuration(600, to: timed, at: day(1))
        let counted = makeMetric(name: "Pages", type: .count)
        addCount(50, to: counted, at: day(1))

        let review = WeeklyReview.build(metrics: [timed, counted])

        #expect(review.totalDuration == 600)
        #expect(review.sessionCount == 2)
    }

    @Test
    func sessionSeriesCombinesMetricsAndFindsBusiestDay() {
        let first = makeMetric(name: "A")
        addDuration(60, to: first, at: day(0))
        addDuration(60, to: first, at: day(0))
        let second = makeMetric(name: "B")
        addDuration(60, to: second, at: day(0))
        addDuration(60, to: second, at: day(2))

        let review = WeeklyReview.build(metrics: [first, second])

        #expect(review.sessionSeries == [0, 0, 0, 0, 1, 0, 3])
        #expect(review.busiestDayOffset == 6)
        #expect(review.activeDays == 2)
        #expect(calendar.isDate(review.day(at: 6), inSameDayAs: .now))
    }
}
