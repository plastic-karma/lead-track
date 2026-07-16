import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The day-browsing half of Today's smart clusters (see
/// `TodayClusters.swift`): every classification and reading anchored to a
/// browsed earlier day instead of the real present, plus the week gate that
/// keeps intentions on the living week. Present-day behavior is covered in
/// `TodayClusterTests` and `TodayClusterReadingTests`.
struct TodayClusterPastDayTests {
    private let calendar = Calendar.current
    /// One anchor per suite, captured at init: helpers that recomputed
    /// startOfDay(.now) per call could split a test's fixtures and
    /// assertions across a midnight crossing.
    private let anchor = Calendar.current.startOfDay(for: .now)

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
            to: anchor
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

    /// A completed session anchored at the given day's midnight, so date
    /// math never straddles day boundaries.
    private func log(
        _ metric: Metric,
        daysAgo: Int,
        seconds: TimeInterval = 600
    ) {
        let start = date(daysAgo)
        let session = Session(
            metric: metric,
            startedAt: start,
            endedAt: start.addingTimeInterval(seconds),
            value: nil
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

    // MARK: - Browsed-day classification

    @Test
    func metricStateReplaysTheBrowsedDay() {
        let metric = makeMetric("Reading", dailyGoal: 180)
        log(metric, daysAgo: 1, seconds: 192)

        #expect(TodayGrouping.metricState(metric, now: date(1)) == .done)
        #expect(TodayGrouping.metricState(metric) == .needsYou)
    }

    @Test
    func completionFractionMeasuresTheBrowsedDay() {
        let metric = makeMetric("Reading", dailyGoal: 100)
        log(metric, daysAgo: 2, seconds: 60)

        #expect(TodayGrouping.completionFraction(metric, now: date(2)) == 0.6)
        #expect(TodayGrouping.completionFraction(metric) == 0)
    }

    @Test
    func restingFollowsTheBrowsedWeekday() {
        let metric = makeMetric("Writing", dailyGoal: 600)
        metric.excludedWeekdays = [weekday(of: date(1))]

        #expect(TodayGrouping.metricState(metric, now: date(1)) == .resting)
        #expect(TodayGrouping.metricState(metric) == .needsYou)
    }

    @Test
    func nextGoalDateWalksFromTheBrowsedDay() throws {
        let metric = makeMetric("Writing", dailyGoal: 600)
        metric.excludedWeekdays = [weekday(of: date(1))]

        let next = try #require(TodayGrouping.nextGoalDate(for: [metric], now: date(1)))

        #expect(calendar.isDate(next, inSameDayAs: anchor))
    }

    // MARK: - Browsed-day readings

    @Test
    func summariesReadTheBrowsedDay() {
        let reading = makeMetric("Reading", dailyGoal: 180)
        log(reading, daysAgo: 3, seconds: 102)

        #expect(TodayGrouping.openSummary(for: [reading], now: date(3)) == "1m 18s left")
        #expect(TodayGrouping.remainingToday(for: reading, now: date(3)) == 78)
        #expect(TodayGrouping.openSummary(for: [reading]) == "3m 00s left")
    }

    @Test
    func doneSummaryTestifiesForTheBrowsedDay() {
        let reading = makeMetric("Reading", dailyGoal: 180)
        log(reading, daysAgo: 1, seconds: 192)

        #expect(TodayGrouping.doneSummary(for: [reading], now: date(1)) == "all done · 3m 12s reading")
    }

    // MARK: - Intentions stay on the living week

    @Test
    func currentWeekIntentionsRideAlongWithinTheWeek() {
        let aspiration = makeAspiration("Kindness", daysAgo: 5)
        let intention = makeIntention("Three kind acts", aspiration: aspiration)
        let weekStart = Intention.weekStart(containing: anchor)

        let clusters = TodayGrouping.clusters(
            metrics: [], aspirations: [aspiration], intentions: [intention],
            now: weekStart
        )

        #expect(clusters.first?.intentions.map(\.title) == ["Three kind acts"])
    }

    @Test
    func intentionsStayHomeBeyondTheWeeksEdge() throws {
        let aspiration = makeAspiration("Kindness", daysAgo: 15)
        let metric = makeMetric("Reading")
        aspiration.metrics.append(metric)
        let intention = makeIntention("Three kind acts", aspiration: aspiration)
        let weekStart = Intention.weekStart(containing: anchor)
        let dayBefore = try #require(calendar.date(byAdding: .day, value: -1, to: weekStart))

        let clusters = TodayGrouping.clusters(
            metrics: [metric], aspirations: [aspiration], intentions: [intention],
            now: dayBefore
        )

        #expect(clusters.count == 1)
        #expect(clusters.first?.intentions.isEmpty == true)
    }

    @Test
    func expiredIntentionsStayHomeEvenInTheirOwnWeek() {
        let aspiration = makeAspiration("Kindness", daysAgo: 15)
        let metric = makeMetric("Reading")
        aspiration.metrics.append(metric)
        let lastWeekStart = Intention.weekStart(containing: date(8))
        let expired = makeIntention(
            "Expired", aspiration: aspiration, weekStart: lastWeekStart
        )

        let clusters = TodayGrouping.clusters(
            metrics: [metric], aspirations: [aspiration], intentions: [expired],
            now: lastWeekStart
        )

        #expect(clusters.count == 1)
        #expect(clusters.first?.intentions.isEmpty == true)
    }

    // MARK: - Browsed-day helper

    @Test
    func dayHelperCountsBackFromNow() {
        #expect(calendar.isDate(TodayGrouping.day(back: 0), inSameDayAs: anchor))
        #expect(calendar.isDate(TodayGrouping.day(back: 1), inSameDayAs: date(1)))
        #expect(calendar.isDate(TodayGrouping.day(back: 9), inSameDayAs: date(9)))
    }
}
