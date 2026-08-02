import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct GoalShortfallTests {
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

    /// Midnight `daysAgo` days back, so fixture sessions never land after
    /// the anchor the asks are computed against.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(byAdding: .day, value: -daysAgo, to: anchor)!
    }

    private var now: Date {
        anchor
    }

    /// Metrics predate the window by default; the live-day gating tests pass
    /// an explicit `createdAt` instead.
    private func goalMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = 600,
        createdAt: Date? = nil
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type, createdAt: createdAt ?? day(30))
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    /// An aspiration holding `metric`, so its ask has a why to nest under.
    private func aspiration(holding metric: Metric) -> Aspiration {
        let aspiration = Aspiration(title: "Grow", createdAt: day(30))
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        aspiration.metrics.append(metric)
        return aspiration
    }

    private func log(_ value: Double, to metric: Metric, on day: Date) {
        let session = metric.measurementType == .duration
            ? Session(metric: metric, startedAt: day, endedAt: day.addingTimeInterval(value))
            : Session(metric: metric, startedAt: day, value: value)
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    private func logEachDay(_ range: ClosedRange<Int>, _ body: (Date) -> Void) {
        for offset in range {
            body(day(offset))
        }
    }

    private func shortfallAsks(
        of metric: Metric,
        holder: Aspiration,
        intentions: [Intention] = []
    ) -> [GoalShortfall.Ask] {
        GoalShortfall.asks(
            for: [metric], aspirations: [holder], intentions: intentions, now: now, calendar: calendar
        )
    }

    // MARK: - Threshold

    @Test
    func fourNoShowDaysRaiseTheAsk() {
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        logEachDay(5 ... 7) { log(600, to: reading, on: $0) } // met thrice, four no-shows

        let asks = shortfallAsks(of: reading, holder: why)

        #expect(asks.map(\.id) == [reading.stableIdentity])
        #expect(asks.first?.goalDays == 7)
        #expect(asks.first?.missedDays == 4)
        #expect(asks.first?.metDays == 3)
    }

    @Test
    func exactlyThreeMissesStaysQuiet() {
        // Met four, missed three — within "more than 3 times". Today is idle
        // and still in progress, so it can never tip the count to four.
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        logEachDay(4 ... 7) { log(600, to: reading, on: $0) }

        #expect(shortfallAsks(of: reading, holder: why).isEmpty)
    }

    @Test
    func shortDaysCountAsMissesLikeNoShows() {
        // A count goal logged under target: showing up short is still an
        // unmet daily goal.
        let pages = goalMetric(name: "Pages", type: .count, dailyGoal: 5)
        let why = aspiration(holding: pages)
        logEachDay(5 ... 7) { log(5, to: pages, on: $0) }
        logEachDay(1 ... 4) { log(2, to: pages, on: $0) }

        let asks = shortfallAsks(of: pages, holder: why)

        #expect(asks.first?.goalDays == 7)
        #expect(asks.first?.missedDays == 4)
    }

    @Test
    func binaryHabitJudgesByShowingUp() {
        // The implicit show-up expectation is the binary habit's daily goal…
        let meditate = goalMetric(name: "Meditate", type: .binary, dailyGoal: nil)
        let why = aspiration(holding: meditate)
        logEachDay(5 ... 7) { log(1, to: meditate, on: $0) }

        #expect(shortfallAsks(of: meditate, holder: why).first?.missedDays == 4)

        // …and releasing the expectation releases the ask.
        meditate.binaryGoalRetiredAt = day(10)
        #expect(shortfallAsks(of: meditate, holder: why).isEmpty)
    }

    @Test
    func metricWithoutADailyGoalStaysQuiet() {
        let reading = goalMetric(dailyGoal: nil)
        let why = aspiration(holding: reading)

        #expect(shortfallAsks(of: reading, holder: why).isEmpty)
    }

    // MARK: - Day accounting

    @Test
    func restDaysDropOutOfTheCount() {
        // Two rest days shrink the judged week to five days, all no-shows.
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        reading.excludedWeekdays = [
            calendar.component(.weekday, from: day(1)),
            calendar.component(.weekday, from: day(2))
        ]

        let asks = shortfallAsks(of: reading, holder: why)

        #expect(asks.first?.goalDays == 5)
        #expect(asks.first?.missedDays == 5)
    }

    @Test
    func enoughRestDaysQuietTheWeek() {
        // Four rest days leave three judged days — three misses at most,
        // never past the threshold.
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        reading.excludedWeekdays = (1 ... 4).map { calendar.component(.weekday, from: day($0)) }

        #expect(shortfallAsks(of: reading, holder: why).isEmpty)
    }

    @Test
    func goalAddedMidWindowOnlyJudgesItsOwnDays() {
        // Three live days can miss at most thrice — a goal added mid-week
        // never turns the earlier days into misses.
        let reading = goalMetric(createdAt: day(3))
        let why = aspiration(holding: reading)

        #expect(shortfallAsks(of: reading, holder: why).isEmpty)
    }

    @Test
    func importedHistoryPredatingCreationStillCounts() {
        // Short sessions imported from before the row existed keep weighing
        // in: the gate is the earliest sign of life, not the row's timestamp.
        let reading = goalMetric(createdAt: now)
        let why = aspiration(holding: reading)
        logEachDay(1 ... 7) { log(300, to: reading, on: $0) }

        let asks = shortfallAsks(of: reading, holder: why)

        #expect(asks.first?.goalDays == 7)
        #expect(asks.first?.missedDays == 7)
    }

    // MARK: - Structural quiets

    @Test
    func unservedMetricIsNeverAsked() {
        // No aspiration, nowhere for an intention to nest — the ask is only
        // made where it can be answered.
        let reading = goalMetric()

        #expect(GoalShortfall.asks(for: [reading], now: now, calendar: calendar).isEmpty)
    }

    @Test
    func openCurrentWeekIntentionAnswersTheAsk() throws {
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        let intention = try Intention.make(
            title: "Three reads", kind: .derived, aspiration: why,
            derivedMode: .sessionCount, metric: reading, target: 3,
            createdAt: now, calendar: calendar
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif

        #expect(shortfallAsks(of: reading, holder: why, intentions: [intention]).isEmpty)

        // Released mid-week, the ask stands again.
        intention.letGo(at: now)
        #expect(shortfallAsks(of: reading, holder: why, intentions: [intention]).count == 1)
    }

    // MARK: - Review wiring

    @Test
    func liveReviewSurfacesAsksAndEarlierWeeksDoNot() {
        let reading = goalMetric()
        let why = aspiration(holding: reading)

        let live = WeeklyReview.build(metrics: [reading], aspirations: [why], now: now)
        let earlier = WeeklyReview.build(metrics: [reading], aspirations: [why], weeksBack: 1, now: now)

        #expect(live.intentionAsks.map(\.id) == [reading.stableIdentity])
        #expect(earlier.intentionAsks.isEmpty)
    }

    @Test
    func archivedMetricsLeaveTheAsks() {
        let reading = goalMetric()
        let why = aspiration(holding: reading)
        reading.archive()

        let review = WeeklyReview.build(metrics: [reading], aspirations: [why], now: now)

        #expect(review.intentionAsks.isEmpty)
    }

    // MARK: - Copy

    @Test
    func detailStatesTheWeekAsFact() {
        let ask = GoalShortfall.Ask(
            id: "m", name: "Reading", icon: "book", colorName: nil,
            goalDays: 7, missedDays: 4
        )

        #expect(ask.detail == "Met on 3 of 7 goal days this past week.")
    }
}
