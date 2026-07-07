import Foundation
import Testing
@testable import lead_track

struct GoalCoachTests {
    /// A pinned Monday-first English calendar so weekday names and spans
    /// don't depend on the machine's locale.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 2
        return calendar
    }

    /// Noon on the given day of a fixed week (0 = Monday, January 12, 2026);
    /// the fallback would fail every assertion loudly rather than crash.
    private func noon(dayIndex: Int) -> Date {
        let components = DateComponents(
            year: 2026, month: 1, day: 12 + dayIndex, hour: 12
        )
        return calendar.date(from: components) ?? .distantPast
    }

    /// The coach only reads `status`, `goal`, and `actual`, so the pace can
    /// be built directly instead of routing through `GoalPace.weekly` and its
    /// `Calendar.current` dependence.
    private func pace(
        actual: Double,
        goal: Double,
        status: GoalPace.Status
    ) -> GoalPace {
        GoalPace(
            actual: actual,
            goal: goal,
            expected: goal / 2,
            projectedTotal: actual,
            status: status
        )
    }

    private func coach(
        _ pace: GoalPace,
        dayIndex: Int,
        excluded: Set<Int> = [],
        type: MeasurementType = .duration
    ) -> GoalCoach {
        GoalCoach(
            pace: pace,
            measurementType: type,
            excludedWeekdays: excluded,
            asOf: noon(dayIndex: dayIndex),
            calendar: calendar
        )
    }

    // MARK: - Status Phrasing

    @Test
    func behindSplitsRemainderAcrossTheRestOfTheWeek() {
        let coach = coach(pace(actual: 6300, goal: 12600, status: .behind), dayIndex: 3)
        #expect(coach.line == "35m/day Fri–Sun reaches the goal")
    }

    @Test
    func onTrackKeepsTheCurrentPerDayPace() {
        let coach = coach(pace(actual: 7200, goal: 12600, status: .onTrack), dayIndex: 3)
        #expect(coach.line == "Keep 30m/day to stay on pace")
    }

    @Test
    func aheadNamesTheLighterFinish() {
        let coach = coach(pace(actual: 9000, goal: 12600, status: .ahead), dayIndex: 3)
        #expect(coach.line == "Ahead of pace — 20m/day Fri–Sun finishes it")
    }

    @Test
    func achievedCelebratesQuietly() {
        let coach = coach(pace(actual: 12600, goal: 12600, status: .achieved), dayIndex: 3)
        #expect(coach.line == "Goal reached — the rest of the week is a bonus")
    }

    // MARK: - Day Spans

    @Test
    func singleRemainingDayIsNamedDirectly() {
        let coach = coach(pace(actual: 10800, goal: 12600, status: .behind), dayIndex: 5)
        #expect(coach.line == "30m/day on Sun reaches the goal")
    }

    @Test
    func restDayGapFallsBackToDayCount() {
        let saturday = 7
        let coach = coach(
            pace(actual: 6300, goal: 12600, status: .behind),
            dayIndex: 3,
            excluded: [saturday]
        )
        #expect(coach.line == "53m/day over 2 days reaches the goal")
    }

    // MARK: - Week Closing

    @Test
    func lastGoalDayPointsAtToday() {
        let coach = coach(pace(actual: 11700, goal: 12600, status: .behind), dayIndex: 6)
        #expect(coach.line == "15m more today reaches the goal")
    }

    @Test
    func lastDayRestingNamesTheGap() {
        let sunday = 1
        let coach = coach(
            pace(actual: 11700, goal: 12600, status: .behind),
            dayIndex: 6,
            excluded: [sunday]
        )
        #expect(coach.line == "15m to go this week")
    }

    // MARK: - Amount Formatting

    @Test
    func countMetricsSplitWholeUnits() {
        let coach = coach(
            pace(actual: 20, goal: 50, status: .behind),
            dayIndex: 3,
            type: .count
        )
        #expect(coach.line == "10/day Fri–Sun reaches the goal")
    }

    @Test
    func durationsRoundUpToTheWholeMinute() {
        let coach = coach(pace(actual: 12000, goal: 12600, status: .behind), dayIndex: 3)
        #expect(coach.line == "4m/day Fri–Sun reaches the goal")
    }
}
