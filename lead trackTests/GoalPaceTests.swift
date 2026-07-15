import Foundation
import Testing
@testable import lead_track

struct GoalPaceTests {
    private let calendar = Calendar.current

    // MARK: - Helpers

    private func weekStart() -> Date {
        calendar.dateInterval(of: .weekOfYear, for: .now)!.start
    }

    private func noon(dayIndex: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: dayIndex, to: weekStart())!
        return calendar.date(byAdding: .hour, value: 12, to: day)!
    }

    private func weekday(dayIndex: Int) -> Int {
        let day = calendar.date(byAdding: .day, value: dayIndex, to: weekStart())!
        return calendar.component(.weekday, from: day)
    }

    // MARK: - Guards

    @Test
    func nilWhenGoalNotPositive() {
        #expect(GoalPace.weekly(actual: 100, goal: 0, asOf: noon(dayIndex: 3)) == nil)
        #expect(GoalPace.weekly(actual: 100, goal: -10, asOf: noon(dayIndex: 3)) == nil)
    }

    @Test
    func nilWhenEveryDayIsRestDay() {
        let pace = GoalPace.weekly(
            actual: 100,
            goal: 1000,
            excludedWeekdays: Set(1 ... 7),
            asOf: noon(dayIndex: 3)
        )
        #expect(pace == nil)
    }

    // MARK: - Expected Pace

    @Test
    func expectedIsProRatedAcrossGoalDays() throws {
        let pace = try #require(GoalPace.weekly(actual: 0, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(abs(pace.expected - 500) < 0.001)
    }

    @Test
    func restDaysRaiseTheExpectation() throws {
        let excluded: Set<Int> = [
            weekday(dayIndex: 4),
            weekday(dayIndex: 5),
            weekday(dayIndex: 6)
        ]
        let result = GoalPace.weekly(
            actual: 0,
            goal: 1000,
            excludedWeekdays: excluded,
            asOf: noon(dayIndex: 3)
        )
        let pace = try #require(result)
        #expect(abs(pace.expected - 875) < 0.001)
    }

    // MARK: - Status

    @Test
    func achievedWhenActualMeetsGoal() throws {
        let pace = try #require(GoalPace.weekly(actual: 1000, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(pace.status == .achieved)
        #expect(pace.projectedToReachGoal)
    }

    @Test
    func aheadWhenAboveExpectedPace() throws {
        let pace = try #require(GoalPace.weekly(actual: 700, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(pace.status == .ahead)
        #expect(pace.delta > 0)
        #expect(pace.projectedToReachGoal)
    }

    @Test
    func behindWhenBelowExpectedPace() throws {
        let pace = try #require(GoalPace.weekly(actual: 300, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(pace.status == .behind)
        #expect(pace.delta < 0)
        #expect(!pace.projectedToReachGoal)
    }

    @Test
    func onTrackWithinTolerance() throws {
        let pace = try #require(GoalPace.weekly(actual: 520, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(pace.status == .onTrack)
    }

    // MARK: - Projection

    @Test
    func projectionNeverBelowActual() throws {
        let pace = try #require(GoalPace.weekly(actual: 480, goal: 1000, asOf: noon(dayIndex: 3)))
        #expect(pace.projectedTotal >= pace.actual)
    }

    @Test
    func projectionClampedToMultipleOfGoal() throws {
        let pace = try #require(GoalPace.weekly(actual: 7000, goal: 10000, asOf: noon(dayIndex: 0)))
        #expect(pace.projectedTotal <= 10000 * 9 + 0.001)
    }

    // MARK: - forWeek

    @Test
    func forWeekIsNilWithoutGoal() {
        #expect(GoalPace.forWeek(dailyTotals: [], weeklyGoal: nil, excludedWeekdays: []) == nil)
    }

    @Test
    func forWeekBuildsPaceFromGoal() {
        let pace = GoalPace.forWeek(dailyTotals: [], weeklyGoal: 1000, excludedWeekdays: [])
        #expect(pace?.goal == 1000)
    }

    // MARK: - Injected Calendar

    @Test
    func injectedCalendarPinsTheWeekStart() throws {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = try #require(TimeZone(identifier: "UTC"))
        utc.firstWeekday = 2 // Monday
        // Wednesday 2026-07-08 noon: Monday and Tuesday elapsed in full plus
        // half of Wednesday — 2.5 of 7 goal days.
        let asOf = try #require(
            utc.date(from: DateComponents(year: 2026, month: 7, day: 8, hour: 12))
        )

        let pace = try #require(GoalPace.weekly(actual: 0, goal: 700, asOf: asOf, calendar: utc))

        #expect(abs(pace.expected - 250) < 0.001)
    }

    @Test
    func dstDayPacesAgainstItsRealLength() throws {
        var newYork = Calendar(identifier: .gregorian)
        newYork.timeZone = try #require(TimeZone(identifier: "America/New_York"))
        newYork.firstWeekday = 1 // Sunday
        // 2026-03-08 springs forward: 1 pm EDT is 12 elapsed hours of a
        // 23-hour day, the sole started goal day of a Sunday-start week.
        let asOf = try #require(
            newYork.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 13))
        )

        let pace = try #require(
            GoalPace.weekly(actual: 0, goal: 700, asOf: asOf, calendar: newYork)
        )

        #expect(abs(pace.expected - 700 * (12.0 / 23.0) / 7.0) < 0.001)
    }
}
