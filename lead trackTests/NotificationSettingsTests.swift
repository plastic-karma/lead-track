import Foundation
import Testing
@testable import lead_track

/// Discreet banner copy under the app lock: metric names, streak counts, and
/// the user's own intention words must stay off the lock screen.
struct NotificationCopyTests {
    @Test
    func discreetReminderCopyOmitsNameAndStreak() {
        let copy = NotificationService.reminderCopy(name: "Therapy", streak: 5, discreet: true)
        #expect(!copy.title.localizedCaseInsensitiveContains("Therapy"))
        #expect(!copy.body.localizedCaseInsensitiveContains("Therapy"))
        #expect(!copy.body.contains("5"))
    }

    @Test
    func standardReminderCopyKeepsNameAndStreak() {
        let copy = NotificationService.reminderCopy(name: "Read", streak: 5, discreet: false)
        #expect(copy.title == "Time to read")
        #expect(copy.body.contains("5-day"))
    }

    @Test
    func reminderCopyWithoutAStreakInvitesTheFirstLog() {
        let copy = NotificationService.reminderCopy(name: "Read", streak: 0, discreet: false)
        #expect(copy.body == "Start building your streak today.")
    }

    @Test
    func discreetStreakAlertOmitsNameAndCount() {
        let copy = NotificationService.streakAlertCopy(name: "Therapy", streak: 12, discreet: true)
        #expect(!copy.title.localizedCaseInsensitiveContains("Therapy"))
        #expect(!copy.body.localizedCaseInsensitiveContains("Therapy"))
        #expect(!copy.body.contains("12"))
    }

    @Test
    func standardStreakAlertNamesTheMetricAndCount() {
        let copy = NotificationService.streakAlertCopy(name: "Read", streak: 12, discreet: false)
        #expect(copy.title == "Read streak at risk")
        #expect(copy.body.contains("12-day"))
    }

    @Test
    func discreetCountdownAndQuestionCopyStayGeneric() {
        let countdown = NotificationService.countdownCopy(name: "Therapy", discreet: true)
        #expect(!countdown.title.localizedCaseInsensitiveContains("Therapy"))
        let question = NotificationService.questionCopy(
            title: "Be present", question: "Did I show up?", discreet: true
        )
        #expect(!question.title.contains("Be present"))
        #expect(!question.body.contains("Did I show up?"))
    }

    @Test
    func standardQuestionCopyIsTheUsersOwnWords() {
        let copy = NotificationService.questionCopy(
            title: "Be present", question: "Did I show up?", discreet: false
        )
        #expect(copy.title == "Be present")
        #expect(copy.body == "Did I show up?")
    }
}

/// A fresh, uniquely named defaults suite per test — swift-testing runs tests
/// in parallel, so a shared suite name would race — removed again on the way
/// out.
private func withTemporaryDefaults(_ body: (UserDefaults) -> Void) throws {
    let suiteName = "lead-track-tests-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }
    body(defaults)
}

/// One source of truth for the review defaults contract shared by the
/// settings sheet and the scheduler.
struct WeeklyReviewSettingsTests {
    @Test
    func keysMatchTheStoredContract() {
        // Renaming a key would silently orphan every user's saved settings.
        #expect(WeeklyReviewSettings.enabledKey == "weeklyReviewEnabled")
        #expect(WeeklyReviewSettings.dayKey == "weeklyReviewDay")
        #expect(WeeklyReviewSettings.hourKey == "weeklyReviewHour")
        #expect(WeeklyReviewSettings.minuteKey == "weeklyReviewMinute")
        #expect(WeeklyReviewSettings.cycleKey == "weeklyReviewCycle")
        #expect(WeeklyReviewSettings.customUnitKey == "weeklyReviewCustomUnit")
        #expect(WeeklyReviewSettings.customIntervalKey == "weeklyReviewCustomInterval")
        #expect(WeeklyReviewSettings.customAnchorKey == "weeklyReviewCustomAnchor")
    }

    @Test
    func untouchedKeysPreserveTheExistingWeeklySchedule() throws {
        try withTemporaryDefaults { defaults in
            #expect(!WeeklyReviewSettings.isEnabled(in: defaults))
            #expect(WeeklyReviewSettings.cycle(in: defaults) == .weekly(weekday: 2))
            #expect(WeeklyReviewSettings.hour(in: defaults) == WeeklyReviewSettings.defaultHour)
            #expect(WeeklyReviewSettings.minute(in: defaults) == WeeklyReviewSettings.defaultMinute)
        }
    }

    @Test
    func existingWeekdaySurvivesTheCycleMigration() throws {
        try withTemporaryDefaults { defaults in
            defaults.set(true, forKey: WeeklyReviewSettings.enabledKey)
            defaults.set(6, forKey: WeeklyReviewSettings.dayKey)
            defaults.set(18, forKey: WeeklyReviewSettings.hourKey)
            defaults.set(30, forKey: WeeklyReviewSettings.minuteKey)
            #expect(WeeklyReviewSettings.isEnabled(in: defaults))
            #expect(WeeklyReviewSettings.cycle(in: defaults) == .weekly(weekday: 6))
            #expect(WeeklyReviewSettings.hour(in: defaults) == 18)
            #expect(WeeklyReviewSettings.minute(in: defaults) == 30)
        }
    }

    @Test
    func customMonthCycleReadsItsIntervalAndAnchor() throws {
        try withTemporaryDefaults { defaults in
            let anchor = Date(timeIntervalSinceReferenceDate: 123_456)
            defaults.set(ReviewCycleKind.custom.rawValue, forKey: WeeklyReviewSettings.cycleKey)
            defaults.set(ReviewCycleUnit.months.rawValue, forKey: WeeklyReviewSettings.customUnitKey)
            defaults.set(2, forKey: WeeklyReviewSettings.customIntervalKey)
            defaults.set(anchor.timeIntervalSinceReferenceDate, forKey: WeeklyReviewSettings.customAnchorKey)
            #expect(WeeklyReviewSettings.cycle(in: defaults) == .everyMonths(2, anchor: anchor))
        }
    }
}

struct ReviewScheduleTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    @Test
    func everyTenDaysStartsAtTheNextPeriodBoundary() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 9, hour: 12)
        let expected = try [
            date(year: 2026, month: 8, day: 19, hour: 9),
            date(year: 2026, month: 8, day: 29, hour: 9),
            date(year: 2026, month: 9, day: 8, hour: 9)
        ]
        let dates = ReviewSchedule.fireDates(
            for: .everyDays(10, anchor: anchor),
            after: now, hour: 9, minute: 0, count: 3, calendar: calendar
        )
        #expect(dates == expected)
    }

    @Test
    func everyTwoWeeksCanBeExpressedAsFourteenDays() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 10)
        let dates = ReviewSchedule.fireDates(
            for: .everyDays(14, anchor: anchor),
            after: now, hour: 8, minute: 30, count: 1, calendar: calendar
        )
        #expect(try dates == [date(year: 2026, month: 8, day: 23, hour: 8, minute: 30)])
    }

    @Test
    func customMonthCycleStartsAtTheFirstOfItsNextPeriod() throws {
        let anchor = try date(year: 2026, month: 8, day: 9)
        let now = try date(year: 2026, month: 8, day: 20)
        let dates = ReviewSchedule.fireDates(
            for: .everyMonths(2, anchor: anchor),
            after: now, hour: 9, minute: 0, count: 2, calendar: calendar
        )
        #expect(try dates == [
            date(year: 2026, month: 10, day: 1, hour: 9),
            date(year: 2026, month: 12, day: 1, hour: 9)
        ])
    }

    @Test
    func calendarPresetsUseMonthQuarterAndYearBoundaries() throws {
        let now = try date(year: 2026, month: 8, day: 9, hour: 12)
        let monthly = firstDate(for: .monthly, after: now)
        let quarterly = firstDate(for: .quarterly, after: now)
        let yearly = firstDate(for: .yearly, after: now)
        let expectedMonthly = try date(year: 2026, month: 9, day: 1, hour: 9)
        let expectedQuarterly = try date(year: 2026, month: 10, day: 1, hour: 9)
        let expectedYearly = try date(year: 2027, month: 1, day: 1, hour: 9)
        #expect(monthly == expectedMonthly)
        #expect(quarterly == expectedQuarterly)
        #expect(yearly == expectedYearly)
    }

    @Test
    func boundaryDayStillFiresTodayBeforeTheChosenTime() throws {
        let now = try date(year: 2026, month: 9, day: 1, hour: 8)
        let expected = try date(year: 2026, month: 9, day: 1, hour: 9)
        #expect(firstDate(for: .monthly, after: now) == expected)
    }

    private func firstDate(for cycle: ReviewCycle, after now: Date) -> Date? {
        ReviewSchedule.fireDates(
            for: cycle, after: now, hour: 9, minute: 0, count: 1, calendar: calendar
        ).first
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) throws -> Date {
        try #require(calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        )))
    }
}

/// Discreet mode keys off the same defaults flag the app lock writes.
struct NotificationPrivacyTests {
    @Test
    func discreetModeFollowsTheAppLockKey() throws {
        try withTemporaryDefaults { defaults in
            // Shared privacy consumers fail closed until the containing app
            // has materialized its migrated lock setting.
            #expect(NotificationPrivacy.isDiscreet(in: defaults))
            defaults.set(false, forKey: AppPrivacySettings.appLockEnabledKey)
            #expect(!NotificationPrivacy.isDiscreet(in: defaults))
            defaults.set(true, forKey: AppPrivacySettings.appLockEnabledKey)
            #expect(NotificationPrivacy.isDiscreet(in: defaults))
        }
    }

    @Test
    func appLockKeysMatchTheSharedContract() {
        #expect(AppPrivacySettings.appLockEnabledKey == "appLockEnabled")
        #expect(AppPrivacySettings.appLockGracePeriodKey == "appLockGracePeriod")
    }
}

/// The slot ceiling shared by the question planner's day loop and
/// `cancelQuestion`'s ID sweep.
struct IntentionQuestionSlotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        return calendar
    }

    @Test
    func plannerNeverPlansMoreSlotsThanTheSharedCeiling() throws {
        let anchor = DateComponents(year: 2026, month: 7, day: 8)
        let week = try #require(calendar.date(from: anchor).flatMap {
            calendar.dateInterval(of: .weekOfYear, for: $0)
        })
        let question = IntentionQuestion(
            text: "Did you get outside today?",
            windowStart: ReminderSchedule.time(hour: 8, calendar: calendar),
            windowEnd: ReminderSchedule.time(hour: 20, calendar: calendar)
        )
        let dates = IntentionQuestionPlanner.fireDates(
            for: question, week: week, seed: 1, now: week.start, calendar: calendar
        )
        #expect(dates.count == IntentionQuestionPlanner.maxSlotsPerWeek)
    }
}
