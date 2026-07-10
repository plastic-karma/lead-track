import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct GoalSeasonTests {
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

    /// Midnight `daysAgo` days back, so date math never straddles `now`.
    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private var now: Date {
        day(0)
    }

    private func makeMetric(
        name: String = "Reading",
        type: MeasurementType = .duration,
        dailyGoal: TimeInterval? = 1800
    ) -> Metric {
        let metric = Metric(name: name, measurementType: type)
        metric.dailyGoal = dailyGoal
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    /// A metric whose season started `weeksAgo` calendar weeks back.
    private func seasoned(_ weeksAgo: Int, length: Int = 6) -> Metric {
        let metric = makeMetric()
        metric.goalSeasonStartedAt = day(weeksAgo * 7)
        metric.goalSeasonWeeks = length
        return metric
    }

    private func addSession(_ metric: Metric, at start: Date, seconds: TimeInterval = 600) {
        let session = Session(
            metric: metric, startedAt: start, endedAt: start.addingTimeInterval(seconds)
        )
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
    }

    // MARK: - Phase

    @Test
    func metricWithoutGoalHasNoPhase() {
        let metric = makeMetric(dailyGoal: nil)
        #expect(GoalSeason.phase(of: metric, now: now) == .none)
    }

    @Test
    func unseasonedLegacyGoalIsNeverDue() {
        let metric = makeMetric()
        #expect(GoalSeason.phase(of: metric, now: now) == .none)
    }

    /// A binary habit's expectation is a target like any other: seasoned, it
    /// phases; released, there is no season left to review.
    @Test
    func binaryHabitSeasonsPhaseWhileExpected() {
        let habit = makeMetric(name: "Show up", type: .binary, dailyGoal: nil)
        habit.goalSeasonStartedAt = day(63)
        habit.goalSeasonWeeks = 6
        #expect(GoalSeason.phase(of: habit, now: now) == .pastSeason(weeksOver: 3))

        habit.binaryGoalRetiredAt = day(1)
        #expect(GoalSeason.phase(of: habit, now: now) == .none)
    }

    @Test
    func binaryReviewRowSaysShowUpDaily() {
        let habit = makeMetric(name: "Show up", type: .binary, dailyGoal: nil)
        habit.goalSeasonStartedAt = day(42)
        habit.goalSeasonWeeks = 6

        let row = GoalSeason.reviews(for: [habit], now: now).first

        #expect(row?.goalText == "Show up daily")
        #expect(row?.phase == .due)
    }

    @Test
    func activeSeasonCountsRemainingWeeks() {
        let metric = seasoned(1)
        #expect(GoalSeason.phase(of: metric, now: now) == .active(weeksRemaining: 5))
    }

    @Test
    func seasonEndIsDue() {
        let metric = seasoned(6)
        #expect(GoalSeason.phase(of: metric, now: now) == .due)
    }

    @Test
    func dueHoldsThroughGrace() {
        let metric = seasoned(7)
        #expect(GoalSeason.phase(of: metric, now: now) == .due)
    }

    @Test
    func graceElapsedIsPastSeason() {
        let metric = seasoned(9)
        #expect(GoalSeason.phase(of: metric, now: now) == .pastSeason(weeksOver: 3))
    }

    // MARK: - Review rows

    @Test
    func reviewsListOnlyDueOrPastMetrics() {
        let active = seasoned(1)
        let due = seasoned(6)
        let unseasoned = makeMetric(name: "Legacy")

        let rows = GoalSeason.reviews(for: [active, due, unseasoned], now: now)

        #expect(rows.map(\.name) == [due.name])
        #expect(rows.first?.phase == .due)
    }

    @Test
    func reviewCarriesGoalTextAndAspirationTitles() {
        let metric = seasoned(6)
        metric.weeklyGoal = 18000
        metric.goalSeasonNote = "See if mornings stick"
        let aspiration = Aspiration(title: "Grow wiser")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        aspiration.metrics.append(metric)

        let row = GoalSeason.reviews(for: [metric], aspirations: [aspiration], now: now).first

        #expect(row?.goalText == "30m 00s / day · 5h 00m / week")
        #expect(row?.seasonNote == "See if mornings stick")
        #expect(row?.aspirationTitles == ["Grow wiser"])
    }

    @Test
    func liveReviewBuildsSeasonRowsAndEarlierWeeksStayEmpty() {
        let due = seasoned(6)
        addSession(due, at: day(1))

        let live = WeeklyReview.build(metrics: [due], now: now)
        let earlier = WeeklyReview.build(metrics: [due], weeksBack: 1, now: now)

        #expect(live.goalSeasonReviews.count == 1)
        #expect(earlier.goalSeasonReviews.isEmpty)
    }

    // MARK: - Decisions

    @Test
    func renewRestampsKeepingLengthAndNote() {
        let metric = seasoned(6, length: 8)
        metric.goalSeasonNote = "Keep going"

        GoalSeason.renew(metric, at: now)

        #expect(metric.goalSeasonStartedAt == now)
        #expect(metric.goalSeasonWeeks == 8)
        #expect(metric.goalSeasonNote == "Keep going")
        #expect(GoalSeason.phase(of: metric, now: now) == .active(weeksRemaining: 8))
    }

    @Test
    func retireClearsGoalsAndSeasonButPreservesRhythm() {
        let metric = seasoned(9)
        metric.weeklyGoal = 18000
        metric.excludedWeekdays = [1, 7]
        metric.reminderTime = day(0)
        metric.streakAlertTime = day(0)

        GoalSeason.retire(metric)

        #expect(metric.dailyGoal == nil)
        #expect(metric.weeklyGoal == nil)
        #expect(metric.goalSeasonStartedAt == nil)
        #expect(metric.goalSeasonWeeks == nil)
        #expect(metric.goalSeasonNote.isEmpty)
        #expect(metric.excludedWeekdays == [1, 7])
        #expect(metric.reminderTime != nil)
        #expect(metric.streakAlertTime != nil)
    }

    @Test
    func retireReleasesBinaryExpectationKeepingEverythingElse() {
        let habit = makeMetric(name: "Show up", type: .binary, dailyGoal: nil)
        habit.goalSeasonStartedAt = day(42)
        habit.goalSeasonWeeks = 6
        addSession(habit, at: day(0))
        #expect(GoalSummary.isDailyComplete(habit))

        GoalSeason.retire(habit, at: now)

        #expect(habit.binaryGoalRetiredAt == now)
        #expect(!habit.expectsDailyShowUp)
        #expect(!GoalSummary.isDailyComplete(habit))
        #expect(GoalSummary.daily(for: [habit]).total == 0)
        #expect(habit.goalSeasonStartedAt == nil)
        #expect(habit.sessions.count == 1)
    }

    /// Daily completion is judged at the injected instant, so completion
    /// around midnight and rest-day boundaries is testable deterministically.
    @Test
    func dailyCompletionEvaluatesAtTheInjectedInstant() {
        let habit = makeMetric(name: "Show up", type: .binary, dailyGoal: nil)
        addSession(habit, at: day(1))

        #expect(GoalSummary.isDailyComplete(habit, now: day(1)))
        #expect(!GoalSummary.isDailyComplete(habit, now: now))
        #expect(GoalSummary.daily(for: [habit], now: day(1)).met == 1)
        #expect(GoalSummary.daily(for: [habit], now: now).met == 0)
    }

    /// The watch mirrors the release: a retired habit leaves the day ring.
    @Test
    func watchRingsDropReleasedBinaryHabit() {
        let live = WatchMetricSnapshot(
            id: UUID(), name: "Live", measurementType: .binary,
            unit: nil, icon: nil, colorName: nil, todayTotal: 1
        )
        let released = WatchMetricSnapshot(
            id: UUID(), name: "Released", measurementType: .binary,
            unit: nil, icon: nil, colorName: nil, todayTotal: 1,
            binaryGoalRetiredAt: day(1)
        )
        let snapshot = WatchSnapshot(metrics: [live, released], day: day(0))

        let summary = ComplicationProgress.dailySummary(in: snapshot)

        #expect(summary.total == 1)
        #expect(summary.met == 1)
    }

    @Test
    func retireLeavesStreakUntouched() {
        let metric = seasoned(6)
        for daysAgo in 0 ... 2 {
            addSession(metric, at: day(daysAgo))
        }
        let before = SessionStatistics.currentStreak(
            from: SessionStatistics.dailyTotals(from: metric.sessions),
            excludedWeekdays: metric.excludedWeekdaySet
        )

        GoalSeason.retire(metric)

        let after = SessionStatistics.currentStreak(
            from: SessionStatistics.dailyTotals(from: metric.sessions),
            excludedWeekdays: metric.excludedWeekdaySet
        )
        #expect(before == 3)
        #expect(after == before)
    }

    // MARK: - Stamping

    @Test
    func stampStartsUnseasonedGoalOnFirstEdit() {
        let metric = makeMetric()

        GoalSeason.stampOnSave(metric, amountsChanged: false, at: now)

        #expect(metric.goalSeasonStartedAt == now)
    }

    @Test
    func stampKeepsClockWhenAmountsUnchanged() {
        let metric = seasoned(2)
        let original = metric.goalSeasonStartedAt

        GoalSeason.stampOnSave(metric, amountsChanged: false, at: now)

        #expect(metric.goalSeasonStartedAt == original)
    }

    @Test
    func stampRestartsClockOnAmountChange() {
        let metric = seasoned(2)

        GoalSeason.stampOnSave(metric, amountsChanged: true, at: now)

        #expect(metric.goalSeasonStartedAt == now)
    }
}
