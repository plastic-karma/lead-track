import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Archiving sets a metric aside without touching its history: it leaves the
/// Today clusters, every corner of the weekly review, and the goal dials, and
/// returns to all of them the moment it is unarchived.
struct MetricArchiveTests {
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

    private func makeMetric(_ name: String = "Reading") -> Metric {
        let metric = Metric(name: name)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeAspiration(_ title: String) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: day(30))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func addDuration(
        _ seconds: TimeInterval,
        to metric: Metric,
        at start: Date
    ) {
        let session = Session(
            metric: metric,
            startedAt: start,
            endedAt: start.addingTimeInterval(seconds)
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    // MARK: - Model

    @Test
    func archiveStampsWhenAndUnarchiveClearsIt() {
        let metric = makeMetric()
        #expect(!metric.isArchived)

        let moment = day(3)
        metric.archive(at: moment)
        #expect(metric.isArchived)
        #expect(metric.archivedAt == moment)

        metric.unarchive()
        #expect(!metric.isArchived)
        #expect(metric.archivedAt == nil)
    }

    @Test
    func unarchivedKeepsOnlyLiveMetricsInOrder() {
        let first = makeMetric("First")
        let resting = makeMetric("Resting")
        let last = makeMetric("Last")
        resting.archive()

        #expect([first, resting, last].unarchived.map(\.name) == ["First", "Last"])
    }

    // MARK: - Today

    @Test
    func archivedMetricLeavesItsTodayCluster() {
        let aspiration = makeAspiration("Grow wiser")
        let kept = makeMetric("Reading")
        let shelved = makeMetric("Guitar")
        aspiration.metrics.append(contentsOf: [kept, shelved])
        shelved.archive()

        let clusters = TodayGrouping.clusters(
            metrics: [kept, shelved], aspirations: [aspiration], intentions: []
        )

        #expect(clusters.count == 1)
        #expect(clusters.first?.metrics.map(\.name) == ["Reading"])
    }

    @Test
    func whollyArchivedDayDissolvesItsClusters() {
        let aspiration = makeAspiration("Grow wiser")
        let aligned = makeMetric("Reading")
        let unaligned = makeMetric("Chores")
        aspiration.metrics.append(aligned)
        aligned.archive()
        unaligned.archive()

        let clusters = TodayGrouping.clusters(
            metrics: [aligned, unaligned], aspirations: [aspiration], intentions: []
        )

        #expect(clusters.isEmpty)
    }

    // MARK: - Weekly review

    @Test
    func archivedMetricLeavesTheWeekEntirely() {
        let kept = makeMetric("Reading")
        let shelved = makeMetric("Guitar")
        addDuration(600, to: kept, at: day(1))
        addDuration(900, to: shelved, at: day(1))
        shelved.archive()

        let review = WeeklyReview.build(metrics: [kept, shelved])

        #expect(review.metricWeeks.map(\.name) == ["Reading"])
        #expect(review.quietMetrics.isEmpty)
        #expect(review.sessionCount == 1)
        #expect(review.totalDuration == 600)
    }

    @Test
    func archivedMetricNeverReadsAsQuiet() {
        let active = makeMetric("Reading")
        let shelved = makeMetric("Guitar")
        addDuration(600, to: active, at: day(1))
        shelved.archive()

        let review = WeeklyReview.build(metrics: [active, shelved])

        #expect(review.quietMetrics.isEmpty)
    }

    @Test
    func archivedSessionsLeaveTheHeaderPulse() {
        let shelved = makeMetric("Guitar")
        addDuration(900, to: shelved, at: day(1))
        shelved.archive()

        let review = WeeklyReview.build(metrics: [shelved])

        #expect(review.sessionSeries.allSatisfy { $0 == 0 })
        #expect(review.activeDays == 0)
    }

    @Test
    func archivedMetricLeavesTheWeeklyGoalDial() {
        let kept = makeMetric("Reading")
        let shelved = makeMetric("Guitar")
        kept.weeklyGoal = 3600
        shelved.weeklyGoal = 3600
        shelved.archive()

        let segments = WeeklyReview.weeklyGoalSegments(metrics: [kept, shelved])

        #expect(segments.map(\.id) == [WeeklyReview.stableID(of: kept)])
    }

    @Test
    func archivedMetricLeavesTheAspirationGroups() {
        let aspiration = makeAspiration("Grow wiser")
        let kept = makeMetric("Reading")
        let shelved = makeMetric("Guitar")
        aspiration.metrics.append(contentsOf: [kept, shelved])
        addDuration(600, to: kept, at: day(1))
        addDuration(900, to: shelved, at: day(1))
        shelved.archive()

        let review = WeeklyReview.build(metrics: [kept, shelved], aspirations: [aspiration])
        let groups = WeeklyReview.metricGroups(
            metrics: [kept, shelved], aspirations: [aspiration],
            weeks: review.metricWeeks, quiet: review.quietMetrics
        )

        #expect(groups.count == 1)
        #expect(groups.first?.weeks.map(\.name) == ["Reading"])
        #expect(groups.first?.quiet.isEmpty == true)
    }

    @Test
    func archivedMetricSilencesItsDueGoalSeason() {
        let metric = makeMetric("Reading")
        metric.dailyGoal = 1800
        metric.goalSeasonStartedAt = day(56)
        metric.goalSeasonWeeks = 4

        #expect(!WeeklyReview.build(metrics: [metric]).goalSeasonReviews.isEmpty)

        metric.archive()
        #expect(WeeklyReview.build(metrics: [metric]).goalSeasonReviews.isEmpty)
    }
}
