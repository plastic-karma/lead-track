import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The render order of Today's smart clusters and the copy readings its
/// stubs and insight lines are built from (see `TodayClusters.swift`): the
/// neediest-first ordering, next goal day, done testimony, and remainders.
/// State classification is covered in `TodayClusterTests`.
struct TodayClusterReadingTests {
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

    private func makeAspiration(_ title: String, daysAgo: Int) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: date(daysAgo))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
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

    // MARK: - Ordering

    @Test
    func needyClustersLeadClosestToCompletionFirst() {
        let farAspiration = makeAspiration("Far", daysAgo: 30)
        let far = makeMetric("FarMetric", dailyGoal: 100)
        logToday(far, seconds: 20)
        farAspiration.metrics.append(far)

        let nearAspiration = makeAspiration("Near", daysAgo: 20)
        let near = makeMetric("NearMetric", dailyGoal: 100)
        logToday(near, seconds: 60)
        nearAspiration.metrics.append(near)

        let doneAspiration = makeAspiration("Settled", daysAgo: 10)
        let done = makeMetric("DoneMetric", dailyGoal: 60)
        logToday(done, seconds: 60)
        doneAspiration.metrics.append(done)

        let clusters = TodayGrouping.clusters(
            metrics: [far, near, done],
            aspirations: [farAspiration, nearAspiration, doneAspiration],
            intentions: []
        )

        #expect(clusters.map(\.aspiration?.title) == ["Near", "Far", "Settled"])
        #expect(clusters.map(\.state) == [.needsYou, .needsYou, .done])
    }

    @Test
    func stubBandsFollowRestingDoneSelfFilling() {
        // Creation order is the reverse of the expected render order, so the
        // state ranking has to do the work.
        let healthAspiration = makeAspiration("Health", daysAgo: 40)
        let health = makeMetric("Calories")
        health.healthSourceRaw = HealthDataSource.activeCalories.rawValue
        healthAspiration.metrics.append(health)

        let doneAspiration = makeAspiration("Settled", daysAgo: 30)
        let done = makeMetric("Done", dailyGoal: 60)
        logToday(done, seconds: 60)
        doneAspiration.metrics.append(done)

        let restingAspiration = makeAspiration("Resting", daysAgo: 20)
        let resting = makeMetric("Writing", dailyGoal: 600)
        resting.excludedWeekdays = [weekday(of: .now)]
        restingAspiration.metrics.append(resting)

        let needyAspiration = makeAspiration("Needy", daysAgo: 10)
        let needy = makeMetric("Open", dailyGoal: 600)
        needyAspiration.metrics.append(needy)

        let clusters = TodayGrouping.clusters(
            metrics: [health, done, resting, needy],
            aspirations: [healthAspiration, doneAspiration, restingAspiration, needyAspiration],
            intentions: []
        )

        #expect(clusters.map(\.state) == [.needsYou, .resting, .done, .selfFilling])
    }

    @Test
    func unalignedClusterTrailsEvenWhenNeedy() {
        let aspiration = makeAspiration("Settled", daysAgo: 10)
        let done = makeMetric("Done", dailyGoal: 60)
        logToday(done, seconds: 60)
        aspiration.metrics.append(done)
        let loose = makeMetric("Chores", dailyGoal: 600)

        let clusters = TodayGrouping.clusters(
            metrics: [done, loose], aspirations: [aspiration], intentions: []
        )

        #expect(clusters.map(\.state) == [.done, .needsYou])
        #expect(clusters.last?.aspiration == nil)
        #expect(clusters.last?.metrics.map(\.name) == ["Chores"])
    }

    // MARK: - Next goal day

    @Test
    func nextGoalDateSkipsExcludedWeekdays() throws {
        let metric = makeMetric("Writing", dailyGoal: 600)
        let dayAfterTomorrow = try #require(
            calendar.date(byAdding: .day, value: 2, to: .now)
        )
        metric.excludedWeekdays = try [
            weekday(of: .now),
            weekday(of: #require(calendar.date(byAdding: .day, value: 1, to: .now)))
        ]

        let next = try #require(TodayGrouping.nextGoalDate(for: [metric]))

        #expect(calendar.isDate(next, inSameDayAs: dayAfterTomorrow))
    }

    @Test
    func nextGoalDateIsNilWhenEveryWeekdayRests() {
        let metric = makeMetric("Writing", dailyGoal: 600)
        metric.excludedWeekdays = Array(1 ... 7)

        #expect(TodayGrouping.nextGoalDate(for: [metric]) == nil)
    }

    // MARK: - Testimony & remainders

    @Test
    func doneSummaryReadsTheDaysSessions() {
        let reading = makeMetric("Reading", dailyGoal: 180)
        logToday(reading, seconds: 192)
        let scripture = makeMetric("Read Scripture", type: .binary)
        logToday(scripture, value: 1)

        let summary = TodayGrouping.doneSummary(for: [reading, scripture])

        #expect(summary == "all done · 3m 12s reading · read scripture kept")
    }

    @Test
    func remainingTodayMeasuresTheGap() {
        let metric = makeMetric("Reading", dailyGoal: 180)
        logToday(metric, seconds: 102)
        let kept = makeMetric("Scripture", type: .binary)

        #expect(TodayGrouping.remainingToday(for: metric) == 78)
        #expect(TodayGrouping.remainingToday(for: kept) == nil)
    }

    // MARK: - Urgency

    @Test
    func urgencyTakesTheClosestUnmetFraction() {
        let far = makeMetric("Far", dailyGoal: 100)
        logToday(far, seconds: 20)
        let near = makeMetric("Near", dailyGoal: 100)
        logToday(near, seconds: 60)
        let over = makeMetric("Over", dailyGoal: 100)
        logToday(over, seconds: 250)

        #expect(TodayGrouping.urgency(of: [far, near]) == 0.6)
        #expect(TodayGrouping.completionFraction(over) == 1)
        #expect(TodayGrouping.neediestMetric(in: [far, near])?.name == "Near")
    }
}
