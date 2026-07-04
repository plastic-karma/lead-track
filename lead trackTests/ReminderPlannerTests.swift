import Foundation
import Testing
@testable import lead_track

struct ReminderPlannerTests {
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
        let components = DateComponents(
            year: 2026, month: 7, day: dayOfMonth, hour: hour
        )
        return calendar.date(from: components) ?? .now
    }

    private func schedule(
        mode: ReminderSchedule.Mode,
        fixedTimes: [Date],
        count: Int = 2
    ) -> ReminderSchedule {
        ReminderSchedule(
            mode: mode,
            fixedTimes: fixedTimes,
            rangeStart: time(8),
            rangeEnd: time(20),
            count: count
        )
    }

    // MARK: - Random minute math

    @Test
    func randomMinutesAreDeterministicForASeed() {
        let first = ReminderPlanner.randomMinutes(in: 480 ... 1200, count: 2, seed: 42)
        let second = ReminderPlanner.randomMinutes(in: 480 ... 1200, count: 2, seed: 42)
        #expect(first == second)
    }

    @Test
    func randomMinutesReturnsDistinctSortedValuesInRange() {
        let minutes = ReminderPlanner.randomMinutes(in: 480 ... 1200, count: 3, seed: 7)
        #expect(minutes.count == 3)
        #expect(minutes == minutes.sorted())
        #expect(Set(minutes).count == 3)
        #expect(minutes.allSatisfy { $0 >= 480 && $0 <= 1200 })
    }

    @Test
    func randomMinutesClampsCountToRangeWidth() {
        // A four-minute-wide window can yield at most four distinct minutes.
        let minutes = ReminderPlanner.randomMinutes(in: 600 ... 603, count: 10, seed: 1)
        #expect(minutes == [600, 601, 602, 603])
    }

    @Test
    func randomMinutesHandlesDegenerateRange() {
        let minutes = ReminderPlanner.randomMinutes(in: 600 ... 600, count: 2, seed: 1)
        #expect(minutes == [600])
    }

    // MARK: - Fire minutes per mode

    @Test
    func fixedModeFiresAtEachDistinctTimeSorted() {
        let plan = schedule(mode: .fixed, fixedTimes: [time(18), time(9), time(9)])
        let minutes = ReminderPlanner.fireMinutes(
            for: plan, on: july(6), seed: 1, calendar: calendar
        )
        #expect(minutes == [9 * 60, 18 * 60])
    }

    @Test
    func randomModeIsDeterministicPerDayAndInRange() {
        let plan = schedule(mode: .random, fixedTimes: [time(9)])
        let target = july(6)
        let first = ReminderPlanner.fireMinutes(for: plan, on: target, seed: 99, calendar: calendar)
        let second = ReminderPlanner.fireMinutes(for: plan, on: target, seed: 99, calendar: calendar)
        #expect(first == second)
        #expect(first.count == 2)
        #expect(first.allSatisfy { $0 >= 8 * 60 && $0 <= 20 * 60 })
    }

    // MARK: - Next fire dates

    @Test
    func nextFireDatesDropsPastFixedTimesToday() throws {
        let plan = schedule(mode: .fixed, fixedTimes: [time(9), time(18)])
        let now = july(6, hour: 12)
        let dates = ReminderPlanner.nextFireDates(
            for: plan, seed: 1, excludedWeekdays: [], now: now, calendar: calendar
        )
        #expect(dates.count == 1)
        #expect(dates.allSatisfy { $0 > now })
        let hour = try #require(dates.first.map { calendar.component(.hour, from: $0) })
        #expect(hour == 18)
    }

    @Test
    func nextFireDatesRollsToNextDayWhenTodayIsSpent() throws {
        let plan = schedule(mode: .fixed, fixedTimes: [time(8), time(9)])
        let now = july(6, hour: 12)
        let dates = ReminderPlanner.nextFireDates(
            for: plan, seed: 1, excludedWeekdays: [], now: now, calendar: calendar
        )
        #expect(dates.count == 2)
        let firstDay = try #require(dates.first.map { calendar.component(.day, from: $0) })
        #expect(firstDay == 7)
    }

    @Test
    func nextFireDatesSkipsRestDays() throws {
        let plan = schedule(mode: .fixed, fixedTimes: [time(9)], count: 1)
        let now = july(6, hour: 6)
        let restDay = calendar.component(.weekday, from: now)
        let dates = ReminderPlanner.nextFireDates(
            for: plan, seed: 1, excludedWeekdays: [restDay], now: now, calendar: calendar
        )
        let firstDay = try #require(dates.first.map { calendar.component(.day, from: $0) })
        #expect(firstDay == 7)
    }

    @Test
    func nextFireDatesEmptyWhenEveryDayIsExcluded() {
        let plan = ReminderSchedule.makeDefault(calendar: calendar)
        let dates = ReminderPlanner.nextFireDates(
            for: plan, seed: 1, excludedWeekdays: Set(1 ... 7), now: july(6), calendar: calendar
        )
        #expect(dates.isEmpty)
    }

    // MARK: - Stable seed

    @Test
    func stableSeedIsStableAndDistinct() throws {
        let first = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let second = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(first.stableSeed == first.stableSeed)
        #expect(first.stableSeed != second.stableSeed)
    }
}

// MARK: - Metric bridging

struct MetricReminderScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    private func time(_ hour: Int) -> Date {
        ReminderSchedule.time(hour: hour, calendar: calendar)
    }

    private func schedule(mode: ReminderSchedule.Mode, count: Int) -> ReminderSchedule {
        ReminderSchedule(
            mode: mode,
            fixedTimes: [time(9), time(18)],
            rangeStart: time(8),
            rangeEnd: time(20),
            count: count
        )
    }

    @Test
    func roundTripsFixedSchedule() {
        let metric = Metric(name: "Read")
        metric.applyReminderSchedule(schedule(mode: .fixed, count: 2))
        let loaded = metric.reminderSchedule
        #expect(loaded?.mode == .fixed)
        #expect(loaded?.fixedTimes.count == 2)
        #expect(metric.reminderTime != nil)
    }

    @Test
    func roundTripsRandomSchedule() {
        let metric = Metric(name: "Read")
        metric.applyReminderSchedule(schedule(mode: .random, count: 3))
        let loaded = metric.reminderSchedule
        #expect(loaded?.mode == .random)
        #expect(loaded?.count == 3)
    }

    @Test
    func clearingScheduleTurnsReminderOff() {
        let metric = Metric(name: "Read")
        metric.applyReminderSchedule(.makeDefault(calendar: calendar))
        metric.applyReminderSchedule(nil)
        #expect(metric.reminderSchedule == nil)
        #expect(metric.reminderTime == nil)
        #expect(metric.reminderTimes.isEmpty)
    }

    @Test
    func legacyReminderTimeMigratesToFixedSchedule() {
        let metric = Metric(name: "Read")
        metric.reminderTime = time(7)
        let loaded = metric.reminderSchedule
        #expect(loaded?.mode == .fixed)
        #expect(loaded?.fixedTimes == [time(7)])
    }
}
