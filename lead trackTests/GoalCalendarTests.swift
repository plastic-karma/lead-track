import Foundation
import Testing
@testable import lead_track

/// Fixed dates throughout — the service takes an explicit `now`, so no case
/// depends on when the suite runs.
struct GoalCalendarTests {
    private let m: ModelFixture
    private let calendar = Calendar.current

    init() throws {
        m = try ModelFixture()
    }

    // MARK: - Fixtures

    /// Noon on the given day, so sessions never straddle a day boundary.
    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(
            from: DateComponents(year: year, month: month, day: day, hour: 12)
        )!
    }

    private func time(on day: Date, hour: Int, minute: Int = 0) -> Date {
        guard let result = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else {
            preconditionFailure("Unable to construct fixture time")
        }
        return result
    }

    private func dayStart(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.startOfDay(for: date(year, month, day))
    }

    /// A duration metric created June 1, 2026 with a one-hour daily goal.
    private func makeGoalMetric(name: String = "Reading") -> Metric {
        let metric = m.makeMetric(name: name)
        metric.createdAt = date(2026, 6, 1)
        metric.dailyGoal = 3600
        return metric
    }

    /// Noon June 20, 2026 — the "now" most cases judge against.
    private var june20: Date {
        date(2026, 6, 20)
    }

    private func outcome(
        _ metric: Metric,
        june day: Int,
        sessions: [Session]? = nil
    ) -> GoalCalendar.DayOutcome? {
        GoalCalendar.outcomes(
            for: metric,
            sessions: sessions ?? metric.sessions,
            monthOf: date(2026, 6, 15),
            now: june20,
            calendar: calendar
        )[dayStart(2026, 6, day)]
    }

    // MARK: - Month grid

    @Test
    func monthGridHoldsEveryDayInOrder() {
        let weeks = GoalCalendar.weeks(inMonthOf: date(2026, 3, 15), calendar: calendar)
        let days = weeks.flatMap { $0 }.compactMap { $0 }
        #expect(days.count == 31)
        #expect(days.first == dayStart(2026, 3, 1))
        #expect(days.last == dayStart(2026, 3, 31))
        #expect(days == days.sorted())
    }

    @Test
    func monthGridRowsAreWeekAligned() {
        let weeks = GoalCalendar.weeks(inMonthOf: date(2026, 3, 15), calendar: calendar)
        for week in weeks {
            #expect(week.count == 7)
            for (column, slot) in week.enumerated() {
                guard let slot else { continue }
                let expected = (calendar.firstWeekday - 1 + column) % 7 + 1
                #expect(calendar.component(.weekday, from: slot) == expected)
            }
        }
    }

    @Test
    func monthGridBlanksOnlyPadTheEdges() {
        let slots = GoalCalendar.weeks(inMonthOf: date(2026, 3, 15), calendar: calendar)
            .flatMap { $0 }
        let first = slots.firstIndex { $0 != nil } ?? 0
        let last = slots.lastIndex { $0 != nil } ?? 0
        #expect(slots[first ... last].allSatisfy { $0 != nil })
    }

    @Test
    func monthStartStepsAcrossYears() {
        #expect(
            GoalCalendar.monthStart(1, from: date(2026, 12, 15), calendar: calendar)
                == dayStart(2027, 1, 1)
        )
        #expect(
            GoalCalendar.monthStart(-1, from: date(2026, 1, 15), calendar: calendar)
                == dayStart(2025, 12, 1)
        )
    }

    @Test
    func weekdaySymbolsStartAtTheCalendarsFirstWeekday() {
        let symbols = GoalCalendar.weekdaySymbols(calendar: calendar)
        #expect(symbols.count == 7)
        #expect(symbols.first == calendar.veryShortWeekdaySymbols[calendar.firstWeekday - 1])
    }

    // MARK: - Series judgment

    @Test
    func durationGoalJudgesMetAndMissed() {
        let metric = makeGoalMetric()
        m.addDuration(4000, to: metric, at: date(2026, 6, 2))
        m.addDuration(1000, to: metric, at: date(2026, 6, 3))
        #expect(outcome(metric, june: 2) == .init(value: 4000, verdict: .met))
        #expect(outcome(metric, june: 3) == .init(value: 1000, verdict: .missed))
        #expect(outcome(metric, june: 4) == .init(value: 0, verdict: .missed))
    }

    @Test
    func restDayHoldsItsValueWithoutJudgment() {
        let metric = makeGoalMetric()
        let sunday = date(2026, 6, 7)
        metric.excludedWeekdays = [calendar.component(.weekday, from: sunday)]
        m.addDuration(1800, to: metric, at: sunday)
        #expect(outcome(metric, june: 7) == .init(value: 1800, verdict: .rest))
    }

    @Test
    func futureAndPreHistoryDaysStayFree() {
        let metric = makeGoalMetric()
        metric.createdAt = date(2026, 6, 10)
        #expect(outcome(metric, june: 21)?.verdict == .free)
        #expect(outcome(metric, june: 5)?.verdict == .free)
        #expect(outcome(metric, june: 10)?.verdict == .missed)
        #expect(outcome(metric, june: 20)?.verdict == .missed)
    }

    @Test
    func backdatedSessionsExtendTheJudgedRange() {
        let metric = makeGoalMetric()
        metric.createdAt = date(2026, 6, 10)
        m.addDuration(4000, to: metric, at: date(2026, 6, 3))
        #expect(outcome(metric, june: 2)?.verdict == .free)
        #expect(outcome(metric, june: 3)?.verdict == .met)
        #expect(outcome(metric, june: 5)?.verdict == .missed)
    }

    @Test
    func binaryMetricJudgesDoneDays() {
        let metric = m.makeMetric(name: "Scripture", type: .binary)
        metric.createdAt = date(2026, 6, 1)
        m.addCount(1, to: metric, at: date(2026, 6, 2))
        #expect(outcome(metric, june: 2)?.verdict == .met)
        #expect(outcome(metric, june: 3)?.verdict == .missed)
    }

    @Test
    func retiredBinaryExpectationLiftsEveryJudgment() {
        let metric = m.makeMetric(name: "Scripture", type: .binary)
        metric.createdAt = date(2026, 6, 1)
        metric.binaryGoalRetiredAt = date(2026, 6, 15)
        m.addCount(1, to: metric, at: date(2026, 6, 2))
        #expect(outcome(metric, june: 2) == .init(value: 1, verdict: .free))
        #expect(outcome(metric, june: 3)?.verdict == .free)
    }

    @Test
    func goallessMetricStaysFreeButKeepsValues() {
        let metric = m.makeMetric(name: "Pages", type: .count, unit: "pages")
        metric.createdAt = date(2026, 6, 1)
        m.addCount(12, to: metric, at: date(2026, 6, 2))
        #expect(outcome(metric, june: 2) == .init(value: 12, verdict: .free))
    }

    @Test
    func runningSessionsNeverCount() {
        let metric = makeGoalMetric()
        m.register(Session(metric: metric, startedAt: date(2026, 6, 2)), metric: metric)
        #expect(outcome(metric, june: 2) == .init(value: 0, verdict: .missed))
    }

    @Test
    func projectSliceIsJudgedAgainstTheMetricGoal() {
        let metric = makeGoalMetric()
        let project = m.makeProject("Novel", of: metric)
        m.addDuration(1800, to: metric, project: project, at: date(2026, 6, 2))
        m.addDuration(2400, to: metric, at: date(2026, 6, 2))
        #expect(
            outcome(metric, june: 2, sessions: project.sessions)
                == .init(value: 1800, verdict: .missed)
        )
        #expect(outcome(metric, june: 2) == .init(value: 4200, verdict: .met))
    }

    @Test
    func projectSliceIsJudgedFromTheProjectsOwnStart() {
        let metric = makeGoalMetric()
        let project = m.makeProject("Novel", of: metric)
        project.startedAt = date(2026, 6, 10)
        m.addDuration(4000, to: metric, project: project, at: date(2026, 6, 12))
        let start = GoalCalendar.trackingStart(of: project, calendar: calendar)
        #expect(start == dayStart(2026, 6, 10))
        let outcomes = GoalCalendar.outcomes(
            for: metric,
            sessions: project.sessions,
            monthOf: date(2026, 6, 15),
            since: start,
            now: june20,
            calendar: calendar
        )
        #expect(outcomes[dayStart(2026, 6, 5)]?.verdict == .free)
        #expect(outcomes[dayStart(2026, 6, 12)]?.verdict == .met)
    }

    @Test
    func dayOutcomeMatchesTheMonthJudgment() {
        let metric = makeGoalMetric()
        m.addDuration(4000, to: metric, at: date(2026, 6, 2))
        let single = GoalCalendar.dayOutcome(
            for: metric,
            sessions: metric.sessions,
            on: date(2026, 6, 2),
            now: june20,
            calendar: calendar
        )
        #expect(single == outcome(metric, june: 2))
    }

    // MARK: - Tallies

    private func tally(_ metrics: [Metric], june day: Int) -> GoalCalendar.DayTally? {
        GoalCalendar.tallies(
            for: metrics,
            monthOf: date(2026, 6, 15),
            now: june20,
            calendar: calendar
        )[dayStart(2026, 6, day)]
    }

    @Test
    func talliesCountOnlyApplicableGoals() {
        let met = makeGoalMetric(name: "Reading")
        let missed = makeGoalMetric(name: "Writing")
        let goalless = m.makeMetric(name: "Pages", type: .count)
        goalless.createdAt = date(2026, 6, 1)
        m.addDuration(4000, to: met, at: date(2026, 6, 2))
        m.addCount(9, to: goalless, at: date(2026, 6, 2))
        #expect(tally([met, missed, goalless], june: 2) == .init(met: 1, total: 2))
    }

    @Test
    func talliesExcludeRestingMetrics() {
        let daily = makeGoalMetric(name: "Reading")
        let resting = makeGoalMetric(name: "Writing")
        let sunday = date(2026, 6, 7)
        resting.excludedWeekdays = [calendar.component(.weekday, from: sunday)]
        #expect(tally([daily, resting], june: 7) == .init(met: 0, total: 1))
        #expect(tally([daily, resting], june: 8) == .init(met: 0, total: 2))
    }

    @Test
    func talliesRespectEachMetricsTrackingStart() {
        let early = makeGoalMetric(name: "Reading")
        let late = makeGoalMetric(name: "Writing")
        late.createdAt = date(2026, 6, 10)
        #expect(tally([early, late], june: 5) == .init(met: 0, total: 1))
        #expect(tally([early, late], june: 12) == .init(met: 0, total: 2))
        #expect(tally([early, late], june: 25) == .init(met: 0, total: 0))
    }

    // MARK: - Month summaries

    @Test
    func seriesSummaryFoldsTheMonth() {
        let metric = makeGoalMetric()
        m.addDuration(4000, to: metric, at: date(2026, 6, 2))
        m.addDuration(1000, to: metric, at: date(2026, 6, 3))
        let summary = GoalCalendar.summary(
            of: GoalCalendar.outcomes(
                for: metric,
                sessions: metric.sessions,
                monthOf: date(2026, 6, 15),
                now: june20,
                calendar: calendar
            )
        )
        #expect(summary == .init(metDays: 1, goalDays: 20, totalValue: 5000))
    }

    @Test
    func tallySummaryTotalsTheMonth() {
        let metric = makeGoalMetric()
        m.addDuration(4000, to: metric, at: date(2026, 6, 2))
        let summary = GoalCalendar.summary(
            of: GoalCalendar.tallies(
                for: [metric],
                monthOf: date(2026, 6, 15),
                now: june20,
                calendar: calendar
            )
        )
        #expect(summary.met == 1)
        #expect(summary.total == 20)
    }

    // MARK: - Rendered month

    private func seriesMonth(for metric: Metric, sessions: [Session]? = nil) -> GoalCalendarMonth {
        GoalCalendarMonth(
            series: GoalCalendarSeries(
                metric: metric,
                sessions: sessions ?? metric.sessions,
                since: GoalCalendar.trackingStart(of: metric, calendar: calendar)
            ),
            talliedMetrics: [],
            monthOf: date(2026, 6, 15),
            now: june20,
            calendar: calendar
        )
    }

    @Test
    func seriesMonthReadsCellsAndSummary() {
        let metric = makeGoalMetric()
        m.addDuration(4000, to: metric, at: date(2026, 6, 2))
        let month = seriesMonth(for: metric)
        #expect(month.fraction(on: dayStart(2026, 6, 2)) == 1)
        #expect(month.fraction(on: dayStart(2026, 6, 3)) == 0)
        #expect(month.fraction(on: dayStart(2026, 6, 25)) == nil)
        #expect(month.cellDetail(on: dayStart(2026, 6, 2)) == "1h06")
        #expect(month.cellDetail(on: dayStart(2026, 6, 3)) == nil)
        #expect(month.summaryText == "Goal met on 1 of 20 days · 1h 06m in all")
    }

    @Test
    func talliedMonthReadsCellsAndSummary() {
        let met = makeGoalMetric(name: "Reading")
        let missed = makeGoalMetric(name: "Writing")
        m.addDuration(4000, to: met, at: date(2026, 6, 2))
        let month = GoalCalendarMonth(
            series: nil,
            talliedMetrics: [met, missed],
            monthOf: date(2026, 6, 15),
            now: june20,
            calendar: calendar
        )
        #expect(month.fraction(on: dayStart(2026, 6, 2)) == 0.5)
        #expect(month.cellDetail(on: dayStart(2026, 6, 2)) == "1/2")
        #expect(month.cellDetail(on: dayStart(2026, 6, 25)) == nil)
        #expect(month.summaryText == "1 of 40 held this month.")
    }

    @Test
    func goallessSeriesMonthSummarizesValueAlone() {
        let metric = m.makeMetric(name: "Pages", type: .count, unit: "pages")
        metric.createdAt = date(2026, 6, 1)
        m.addCount(12, to: metric, at: date(2026, 6, 2))
        let month = seriesMonth(for: metric)
        #expect(month.fraction(on: dayStart(2026, 6, 2)) == nil)
        #expect(month.cellDetail(on: dayStart(2026, 6, 2)) == "12")
        #expect(month.summaryText == "No daily goal to judge · 12 pages in all")
    }

    @Test
    func emptyTalliedMonthSaysSo() {
        let month = GoalCalendarMonth(
            series: nil,
            talliedMetrics: [],
            monthOf: date(2026, 6, 15),
            now: june20,
            calendar: calendar
        )
        #expect(month.summaryText == "No daily goals this month.")
        #expect(month.weeks.flatMap { $0 }.compactMap { $0 }.count == 30)
    }
}

// MARK: - Moments

extension GoalCalendarTests {
    @Test
    func momentsBucketByOccurredAtAndReadChronologically() {
        let growth = m.makeAspiration("Grow")
        let wonder = m.makeAspiration("Wonder")
        let morning = Moment(
            text: "Morning",
            aspiration: growth,
            occurredAt: time(on: date(2026, 6, 2), hour: 8),
            createdAt: date(2026, 7, 4)
        )
        let evening = Moment(
            text: "Evening",
            aspiration: wonder,
            occurredAt: time(on: date(2026, 6, 2), hour: 19),
            createdAt: date(2026, 5, 1)
        )

        let grouped = GoalCalendar.momentsByDay(
            [evening, morning], monthOf: date(2026, 6, 15), calendar: calendar
        )

        #expect(grouped[dayStart(2026, 6, 2)]?.map(\.text) == ["Morning", "Evening"])
        #expect(
            grouped.values.flatMap { $0 }.compactMap(\.aspiration?.title).sorted()
                == ["Grow", "Wonder"]
        )
    }

    @Test
    func momentMonthWindowIsHalfOpen() {
        let aspiration = m.makeAspiration()
        let moments = [
            Moment(
                text: "May",
                aspiration: aspiration,
                occurredAt: time(on: date(2026, 5, 31), hour: 23, minute: 59)
            ),
            Moment(
                text: "First",
                aspiration: aspiration,
                occurredAt: dayStart(2026, 6, 1)
            ),
            Moment(
                text: "Last",
                aspiration: aspiration,
                occurredAt: time(on: date(2026, 6, 30), hour: 23, minute: 59)
            ),
            Moment(
                text: "July",
                aspiration: aspiration,
                occurredAt: dayStart(2026, 7, 1)
            )
        ]

        let grouped = GoalCalendar.momentsByDay(
            moments, monthOf: date(2026, 6, 15), calendar: calendar
        )

        #expect(grouped.keys.sorted() == [dayStart(2026, 6, 1), dayStart(2026, 6, 30)])
        #expect(grouped.values.flatMap { $0 }.map(\.text).sorted() == ["First", "Last"])
    }
}
