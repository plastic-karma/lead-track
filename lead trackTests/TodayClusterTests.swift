import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The classification half of Today's smart clusters (see
/// `TodayClusters.swift`): metric and cluster states, and which intentions
/// join which cluster. Ordering and the stub/insight readings are covered in
/// `TodayClusterReadingTests`.
struct TodayClusterTests {
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

    private func date(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func makeMetric(
        _ name: String,
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type)
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeAspiration(_ title: String, daysAgo: Int) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: date(daysAgo))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeIntention(
        _ title: String,
        aspiration: Aspiration,
        weekStart: Date? = nil
    ) -> Intention {
        let intention = Intention(
            title: title, kind: .counted, aspiration: aspiration,
            target: 3, weekStart: weekStart ?? Intention.weekStart(containing: .now)
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    /// A completed session anchored at today's midnight, so date math never
    /// straddles `now`.
    private func logToday(
        _ metric: Metric,
        seconds: TimeInterval = 600,
        value: Double? = nil
    ) {
        let start = calendar.startOfDay(for: .now)
        let session = Session(
            metric: metric,
            startedAt: start,
            endedAt: value == nil ? start.addingTimeInterval(seconds) : start,
            value: value
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func weekday(of day: Date) -> Int {
        calendar.component(.weekday, from: day)
    }

    // MARK: - Metric states

    @Test
    func healthLinkedMetricSelfFillsEvenWithAnUnmetGoal() {
        let metric = makeMetric("Calories", dailyGoal: 600)
        metric.healthSourceRaw = HealthDataSource.activeCalories.rawValue

        #expect(TodayGrouping.metricState(metric) == .selfFilling)
    }

    @Test
    func goalLessMetricAlwaysNeedsYou() {
        let metric = makeMetric("Reading")
        logToday(metric)

        #expect(TodayGrouping.metricState(metric) == .needsYou)
    }

    @Test
    func dailyGoalWalksFromNeedsYouToDone() {
        let metric = makeMetric("Reading", dailyGoal: 180)
        logToday(metric, seconds: 100)
        #expect(TodayGrouping.metricState(metric) == .needsYou)

        logToday(metric, seconds: 92)
        #expect(TodayGrouping.metricState(metric) == .done)
    }

    @Test
    func binaryHabitNeedsYouUntilKept() {
        let metric = makeMetric("Scripture", type: .binary)
        #expect(TodayGrouping.metricState(metric) == .needsYou)

        logToday(metric, value: 1)
        #expect(TodayGrouping.metricState(metric) == .done)
    }

    @Test
    func retiredBinaryHabitReadsGoalLess() {
        let metric = makeMetric("Scripture", type: .binary)
        metric.binaryGoalRetiredAt = date(1)

        #expect(TodayGrouping.metricState(metric) == .needsYou)
    }

    @Test
    func excludedWeekdayRests() {
        let metric = makeMetric("Writing", dailyGoal: 600)
        metric.excludedWeekdays = [weekday(of: .now)]

        #expect(TodayGrouping.metricState(metric) == .resting)
    }

    // MARK: - Cluster states

    @Test
    func clusterNeedsYouWhenAnyMemberDoes() {
        let done = makeMetric("Done", dailyGoal: 60)
        logToday(done, seconds: 60)
        let open = makeMetric("Open", dailyGoal: 600)

        #expect(TodayGrouping.clusterState(of: [done, open]) == .needsYou)
    }

    @Test
    func clusterDoneWhenEveryMetricTargetedTodayIsMet() {
        let done = makeMetric("Done", dailyGoal: 60)
        logToday(done, seconds: 60)
        let resting = makeMetric("Resting", dailyGoal: 600)
        resting.excludedWeekdays = [weekday(of: .now)]

        #expect(TodayGrouping.clusterState(of: [done, resting]) == .done)
    }

    @Test
    func clusterRestsWhenOnlyRestersRemain() {
        let resting = makeMetric("Resting", dailyGoal: 600)
        resting.excludedWeekdays = [weekday(of: .now)]
        let health = makeMetric("Calories")
        health.healthSourceRaw = HealthDataSource.activeCalories.rawValue

        #expect(TodayGrouping.clusterState(of: [resting, health]) == .resting)
        #expect(TodayGrouping.clusterState(of: [health]) == .selfFilling)
        #expect(TodayGrouping.clusterState(of: []) == .resting)
    }

    // MARK: - Intentions

    @Test
    func intentionOnlyAspirationFormsARestingCluster() {
        let aspiration = makeAspiration("Kindness", daysAgo: 5)
        let intention = makeIntention("Three kind acts", aspiration: aspiration)

        let clusters = TodayGrouping.clusters(
            metrics: [], aspirations: [aspiration], intentions: [intention]
        )

        #expect(clusters.count == 1)
        #expect(clusters.first?.state == .resting)
        #expect(clusters.first?.intentions.map(\.title) == ["Three kind acts"])
    }

    @Test
    func onlyOpenCurrentWeekIntentionsJoinTheirCluster() {
        let aspiration = makeAspiration("Kindness", daysAgo: 5)
        let other = makeAspiration("Elsewhere", daysAgo: 4)
        let current = makeIntention("Stays", aspiration: aspiration)
        let closed = makeIntention("Closed", aspiration: aspiration)
        closed.letGo()
        let lastWeek = makeIntention(
            "Expired", aspiration: aspiration,
            weekStart: Intention.weekStart(containing: date(7))
        )
        let elsewhere = makeIntention("Neighbor", aspiration: other)

        let clusters = TodayGrouping.clusters(
            metrics: [], aspirations: [aspiration, other],
            intentions: [current, closed, lastWeek, elsewhere]
        )

        #expect(clusters.first?.intentions.map(\.title) == ["Stays"])
        #expect(clusters.last?.intentions.map(\.title) == ["Neighbor"])
    }
}
