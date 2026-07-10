import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The logging-today regression suite: a log must roll the metric's
/// notifications forward to the next goal day, never unarm them — plus the
/// planner's skip-today walk that makes the roll possible.
struct NotificationPlanningTests {
    /// A UTC calendar keeps the day and hour assertions independent of the
    /// host time zone, so they are stable in CI.
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

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

    /// A July 2026 instant at the given day-of-month and hour, in UTC.
    /// July 6, 2026 is a Monday; weekday 3 is Tuesday.
    private func july(_ dayOfMonth: Int, hour: Int = 0) -> Date {
        let components = DateComponents(year: 2026, month: 7, day: dayOfMonth, hour: hour)
        return calendar.date(from: components) ?? .now
    }

    private func time(_ hour: Int) -> Date {
        ReminderSchedule.time(hour: hour, calendar: calendar)
    }

    private func fixedSchedule(hours: [Int]) -> ReminderSchedule {
        ReminderSchedule(
            mode: .fixed,
            fixedTimes: hours.map(time),
            rangeStart: time(8),
            rangeEnd: time(20),
            count: 2
        )
    }

    private func makeMetric(reminderHours: [Int] = []) -> Metric {
        let metric = Metric(name: "Meditate")
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        if !reminderHours.isEmpty {
            metric.applyReminderSchedule(fixedSchedule(hours: reminderHours))
        }
        return metric
    }

    private func log(_ metric: Metric, at date: Date) {
        let session = Session(startedAt: date, endedAt: date.addingTimeInterval(600))
        #if canImport(SwiftData)
        context.insert(session)
        #endif
        metric.sessions.append(session)
    }

    private func dayOfMonth(_ date: Date) -> Int {
        calendar.component(.day, from: date)
    }

    // MARK: - Planner: skipping today

    @Test
    func skippingTodayRollsToTomorrowEvenWithFiresStillAhead() throws {
        let dates = ReminderPlanner.nextFireDates(
            for: fixedSchedule(hours: [9, 18]), seed: 1, excludedWeekdays: [],
            now: july(6, hour: 12), calendar: calendar, skippingToday: true
        )
        #expect(dates.count == 2)
        let firstDay = try #require(dates.first.map { dayOfMonth($0) })
        #expect(firstDay == 7)
    }

    @Test
    func skippingTodayStillHonorsRestDays() throws {
        // Tuesday July 7 rests, so the skip lands on Wednesday the 8th.
        let dates = ReminderPlanner.nextFireDates(
            for: fixedSchedule(hours: [9]), seed: 1, excludedWeekdays: [3],
            now: july(6, hour: 8), calendar: calendar, skippingToday: true
        )
        let firstDay = try #require(dates.first.map { dayOfMonth($0) })
        #expect(firstDay == 8)
    }

    @Test
    func withoutSkippingTodayTheRemainingFiresStayToday() throws {
        let dates = ReminderPlanner.nextFireDates(
            for: fixedSchedule(hours: [9, 18]), seed: 1, excludedWeekdays: [],
            now: july(6, hour: 12), calendar: calendar
        )
        #expect(dates.count == 1)
        let firstDay = try #require(dates.first.map { dayOfMonth($0) })
        #expect(firstDay == 6)
    }

    // MARK: - Planner: next goal moment

    @Test
    func nextGoalMomentPicksTodayWhileTheTimeIsAhead() throws {
        let moment = try #require(ReminderPlanner.nextGoalMoment(
            at: time(20), excludedWeekdays: [], now: july(6, hour: 12), calendar: calendar
        ))
        #expect(dayOfMonth(moment) == 6)
        #expect(calendar.component(.hour, from: moment) == 20)
    }

    @Test
    func nextGoalMomentRollsPastSpentTimesAndRestDays() throws {
        // Monday's 9am is spent and Tuesday rests, so Wednesday 9am.
        let moment = try #require(ReminderPlanner.nextGoalMoment(
            at: time(9), excludedWeekdays: [3], now: july(6, hour: 12), calendar: calendar
        ))
        #expect(dayOfMonth(moment) == 8)
        #expect(calendar.component(.hour, from: moment) == 9)
    }

    @Test
    func nextGoalMomentSkippingTodayIgnoresATimeStillAhead() throws {
        let moment = try #require(ReminderPlanner.nextGoalMoment(
            at: time(20), excludedWeekdays: [], now: july(6, hour: 12),
            calendar: calendar, skippingToday: true
        ))
        #expect(dayOfMonth(moment) == 7)
    }

    @Test
    func nextGoalMomentIsNilWhenEveryWeekdayRests() {
        let moment = ReminderPlanner.nextGoalMoment(
            at: time(9), excludedWeekdays: Set(1 ... 7), now: july(6), calendar: calendar
        )
        #expect(moment == nil)
    }

    // MARK: - Reminders after logging

    @Test
    func loggingTodayKeepsTomorrowsRemindersArmed() {
        let metric = makeMetric(reminderHours: [9, 18])
        log(metric, at: july(6, hour: 8))
        let dates = NotificationService.reminderFireDates(
            for: metric, now: july(6, hour: 12), calendar: calendar
        )
        #expect(!dates.isEmpty)
        #expect(dates.allSatisfy { dayOfMonth($0) == 7 })
    }

    @Test
    func anUnloggedDayKeepsTodaysRemainingReminder() throws {
        let metric = makeMetric(reminderHours: [9, 18])
        log(metric, at: july(5, hour: 9))
        let dates = NotificationService.reminderFireDates(
            for: metric, now: july(6, hour: 12), calendar: calendar
        )
        #expect(dates.count == 1)
        let firstDay = try #require(dates.first.map { dayOfMonth($0) })
        #expect(firstDay == 6)
    }

    @Test
    func loggingTodayWithTomorrowRestingArmsTheNextGoalDay() {
        let metric = makeMetric(reminderHours: [9])
        metric.excludedWeekdays = [3]
        log(metric, at: july(6, hour: 7))
        let dates = NotificationService.reminderFireDates(
            for: metric, now: july(6, hour: 8), calendar: calendar
        )
        #expect(!dates.isEmpty)
        #expect(dates.allSatisfy { dayOfMonth($0) == 8 })
    }

    @Test
    func reminderFireDatesAreEmptyWithoutASchedule() {
        let metric = makeMetric()
        log(metric, at: july(6, hour: 8))
        let dates = NotificationService.reminderFireDates(
            for: metric, now: july(6, hour: 12), calendar: calendar
        )
        #expect(dates.isEmpty)
    }

    // MARK: - Streak alert after logging

    @Test
    func streakAlertRearmsForTheNextGoalDayOnceTodayIsLogged() throws {
        let metric = makeMetric()
        metric.streakAlertTime = time(20)
        log(metric, at: july(6, hour: 8))
        let date = try #require(NotificationService.streakAlertFireDate(
            for: metric, now: july(6, hour: 12), calendar: calendar
        ))
        #expect(dayOfMonth(date) == 7)
        #expect(calendar.component(.hour, from: date) == 20)
    }

    @Test
    func streakAlertStaysOnTodayWhileUnlogged() throws {
        let metric = makeMetric()
        metric.streakAlertTime = time(20)
        log(metric, at: july(5, hour: 9))
        let date = try #require(NotificationService.streakAlertFireDate(
            for: metric, now: july(6, hour: 12), calendar: calendar
        ))
        #expect(dayOfMonth(date) == 6)
    }

    @Test
    func streakAlertFireDateIsNilWithoutAnAlertTime() {
        let metric = makeMetric()
        let date = NotificationService.streakAlertFireDate(
            for: metric, now: july(6, hour: 12), calendar: calendar
        )
        #expect(date == nil)
    }

    // MARK: - Logged today

    @Test
    func hasLoggedTodayIgnoresRunningAndPastSessions() {
        let metric = makeMetric()
        log(metric, at: july(5, hour: 9))
        let running = Session(startedAt: july(6, hour: 9))
        #if canImport(SwiftData)
        context.insert(running)
        #endif
        metric.sessions.append(running)
        #expect(!NotificationService.hasLoggedToday(metric, now: july(6, hour: 12), calendar: calendar))
        log(metric, at: july(6, hour: 10))
        #expect(NotificationService.hasLoggedToday(metric, now: july(6, hour: 12), calendar: calendar))
    }
}
