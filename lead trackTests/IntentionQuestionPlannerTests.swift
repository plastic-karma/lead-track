import Foundation
import Testing
@testable import lead_track

/// The daily-question planner: one seeded-random ask per remaining day of the
/// intention's week, deterministic across reschedules, clamped to the week
/// and to moments still ahead of now.
struct IntentionQuestionPlannerTests {
    /// A UTC calendar keeps minute-of-day extraction independent of the host
    /// time zone, so the hour assertions below are stable in CI.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    // MARK: - Fixtures

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        ReminderSchedule.time(hour: hour, minute: minute, calendar: calendar)
    }

    /// A July 2026 instant at the given day-of-month and hour, in UTC.
    private func july(_ dayOfMonth: Int, hour: Int = 0) -> Date {
        let components = DateComponents(year: 2026, month: 7, day: dayOfMonth, hour: hour)
        return calendar.date(from: components) ?? .now
    }

    /// The calendar week containing the given instant — computed, never
    /// hardcoded, so the tests hold for any `firstWeekday`.
    private func week(containing date: Date) throws -> DateInterval {
        try #require(calendar.dateInterval(of: .weekOfYear, for: date))
    }

    private func question(from start: Date? = nil, to end: Date? = nil) -> IntentionQuestion {
        IntentionQuestion(
            text: "Did you get outside today?",
            windowStart: start ?? time(8),
            windowEnd: end ?? time(20)
        )
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    // MARK: - Shape of the plan

    @Test
    func plansAreDeterministicForASeed() throws {
        let week = try week(containing: july(8))
        let first = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 42, now: week.start, calendar: calendar
        )
        let second = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 42, now: week.start, calendar: calendar
        )
        #expect(first == second)
        #expect(!first.isEmpty)
    }

    @Test
    func plansOneAskPerRemainingDayAscending() throws {
        let week = try week(containing: july(8))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.start, calendar: calendar
        )
        #expect(dates.count == 7)
        #expect(dates == dates.sorted())
        let days = dates.map { calendar.startOfDay(for: $0) }
        #expect(Set(days).count == 7)
        #expect(dates.allSatisfy { week.contains($0) && $0 < week.end })
    }

    @Test
    func everyAskLandsInsideTheWindow() throws {
        let week = try week(containing: july(8))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.start, calendar: calendar
        )
        #expect(dates.allSatisfy { minuteOfDay($0) >= 8 * 60 && minuteOfDay($0) <= 20 * 60 })
    }

    // MARK: - Now handling

    @Test
    func todayIsIncludedWhileItsAskIsStillAhead() throws {
        let week = try week(containing: july(8))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.start, calendar: calendar
        )
        let firstDay = try #require(dates.first.map { calendar.startOfDay(for: $0) })
        #expect(firstDay == week.start)
    }

    @Test
    func todayDropsOutOnceItsAskHasPassed() throws {
        let week = try week(containing: july(8))
        let fullPlan = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.start, calendar: calendar
        )
        let firstAsk = try #require(fullPlan.first)
        let remainder = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: firstAsk, calendar: calendar
        )
        #expect(remainder == Array(fullPlan.dropFirst()))
    }

    @Test
    func plansNothingOnceTheWeekIsOver() throws {
        let week = try week(containing: july(8))
        let atEnd = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.end, calendar: calendar
        )
        let past = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.end.addingTimeInterval(86400), calendar: calendar
        )
        #expect(atEnd.isEmpty)
        #expect(past.isEmpty)
    }

    @Test
    func lastDayPlansAtMostOneAskInsideTheWeek() throws {
        let week = try week(containing: july(8))
        let lastDay = try #require(calendar.date(byAdding: .day, value: -1, to: week.end))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: lastDay, calendar: calendar
        )
        #expect(dates.count == 1)
        #expect(dates.allSatisfy { $0 < week.end })
    }

    // MARK: - Window edge cases

    @Test
    func invertedWindowBoundsAreSwapped() throws {
        let week = try week(containing: july(8))
        let straight = IntentionQuestionPlanner.fireDates(
            for: question(from: time(8), to: time(20)),
            week: week, seed: 7, now: week.start, calendar: calendar
        )
        let inverted = IntentionQuestionPlanner.fireDates(
            for: question(from: time(20), to: time(8)),
            week: week, seed: 7, now: week.start, calendar: calendar
        )
        #expect(straight == inverted)
    }

    @Test
    func degenerateWindowPinsTheMinute() throws {
        let week = try week(containing: july(8))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(from: time(9, 30), to: time(9, 30)),
            week: week, seed: 7, now: week.start, calendar: calendar
        )
        #expect(dates.count == 7)
        #expect(dates.allSatisfy { minuteOfDay($0) == 9 * 60 + 30 })
    }

    // MARK: - Seeding

    @Test
    func differentSeedsDrawDifferentPlans() throws {
        let week = try week(containing: july(8))
        let first = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 1, now: week.start, calendar: calendar
        )
        let second = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 2, now: week.start, calendar: calendar
        )
        #expect(first != second)
    }

    @Test
    func thePerDayMixVariesTheMinuteAcrossTheWeek() throws {
        let week = try week(containing: july(8))
        let dates = IntentionQuestionPlanner.fireDates(
            for: question(), week: week, seed: 7, now: week.start, calendar: calendar
        )
        let minutes = Set(dates.map(minuteOfDay))
        #expect(minutes.count > 1)
    }
}
