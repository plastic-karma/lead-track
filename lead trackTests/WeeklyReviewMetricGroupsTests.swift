import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct WeeklyReviewMetricGroupsTests {
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

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeMetric(
        _ name: String,
        weeklyGoal: TimeInterval? = nil,
        dailyGoal: TimeInterval? = nil
    ) -> Metric {
        let metric = Metric(name: name)
        metric.weeklyGoal = weeklyGoal
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeAspiration(_ title: String, daysAgo: Int) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: day(daysAgo))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func addDuration(_ seconds: TimeInterval, to metric: Metric, at start: Date) {
        let session = Session(metric: metric, startedAt: start, endedAt: start.addingTimeInterval(seconds))
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func groups(_ metrics: [Metric], _ aspirations: [Aspiration]) -> [WeeklyReview.MetricGroup] {
        let review = WeeklyReview.build(metrics: metrics, aspirations: aspirations)
        return WeeklyReview.metricGroups(
            metrics: metrics, aspirations: aspirations,
            weeks: review.metricWeeks, quiet: review.quietMetrics
        )
    }

    // MARK: - Grouping

    @Test
    func activeMetricsGroupUnderTheirAspiration() {
        let aspiration = makeAspiration("Grow wiser", daysAgo: 20)
        let reading = makeMetric("Reading")
        addDuration(600, to: reading, at: day(1))
        aspiration.metrics.append(reading)

        let result = groups([reading], [aspiration])

        #expect(result.count == 1)
        #expect(result.first?.title == "Grow wiser")
        #expect(result.first?.weeks.map(\.name) == ["Reading"])
        #expect(result.first?.quiet.isEmpty == true)
    }

    @Test
    func quietMetricRidesAlongInsideAnActiveGroup() {
        let aspiration = makeAspiration("Grow wiser", daysAgo: 20)
        let active = makeMetric("Reading")
        addDuration(600, to: active, at: day(1))
        let silent = makeMetric("Journaling")
        aspiration.metrics.append(contentsOf: [active, silent])

        let result = groups([active, silent], [aspiration])

        #expect(result.count == 1)
        #expect(result.first?.weeks.map(\.name) == ["Reading"])
        #expect(result.first?.quiet.map(\.name) == ["Journaling"])
    }

    @Test
    func whollyQuietAspirationProducesNoGroup() {
        let aspiration = makeAspiration("Resting", daysAgo: 20)
        let silent = makeMetric("Journaling")
        aspiration.metrics.append(silent)

        let result = groups([silent], [aspiration])

        #expect(result.isEmpty)
    }

    @Test
    func unalignedActiveMetricsTrailInTheirOwnGroup() {
        let aspiration = makeAspiration("Grow wiser", daysAgo: 20)
        let reading = makeMetric("Reading")
        addDuration(600, to: reading, at: day(1))
        aspiration.metrics.append(reading)
        let chores = makeMetric("Chores")
        addDuration(300, to: chores, at: day(2))

        let result = groups([reading, chores], [aspiration])

        #expect(result.map(\.id) == [aspiration.stableID?.uuidString, "unaligned"])
        #expect(result.last?.title == "Unaligned Effort")
        #expect(result.last?.weeks.map(\.name) == ["Chores"])
    }

    // MARK: - Weekly-goal dial

    @Test
    func dialSegmentForWeeklyGoalAndNoneForAGoallessMetric() {
        let tracked = makeMetric("Reading", weeklyGoal: 3600)
        addDuration(1800, to: tracked, at: day(1))
        let goalless = makeMetric("Chores")
        addDuration(600, to: goalless, at: day(1))

        let segments = WeeklyReview.weeklyGoalSegments(metrics: [tracked, goalless])

        #expect(segments.map(\.id) == [tracked.stableID?.uuidString])
        #expect(segments.first?.fraction == 0.5)
    }

    @Test
    func dialSegmentForADailyGoalSpreadOverTheWeek() {
        // 600s/day × 7 scheduled days = 4200s week target; 2100 logged = half.
        let daily = makeMetric("Pushups", dailyGoal: 600)
        addDuration(2100, to: daily, at: day(1))

        let segments = WeeklyReview.weeklyGoalSegments(metrics: [daily])

        #expect(segments.count == 1)
        #expect(segments.first?.fraction == 0.5)
    }

    @Test
    func dialFractionCapsAtOne() {
        let tracked = makeMetric("Reading", weeklyGoal: 3600)
        addDuration(7200, to: tracked, at: day(1))

        let segments = WeeklyReview.weeklyGoalSegments(metrics: [tracked])

        #expect(segments.first?.fraction == 1)
    }
}
