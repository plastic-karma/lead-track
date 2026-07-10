#if canImport(UserNotifications)
import Foundation
import SwiftData
import UserNotifications

enum NotificationService {
    static func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.alert, .sound]
        ) { _, _ in }
    }

    static func rescheduleAll(
        container: ModelContainer
    ) {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<Metric>()
        guard let metrics = try? context.fetch(descriptor)
        else { return }
        UNUserNotificationCenter.current()
            .removeAllPendingNotificationRequests()
        // Archived metrics rest silently — no reminders, no streak nudges,
        // and no mention in the weekly review summary.
        let live = metrics.unarchived
        for metric in live {
            scheduleReminder(for: metric)
            scheduleStreakAlert(for: metric)
            scheduleRunningCountdown(for: metric)
        }
        scheduleWeeklyReview(metrics: live)
        scheduleAllIntentionQuestions(in: context)
    }

    static func rescheduleMetric(
        _ metric: Metric
    ) {
        cancelForMetric(metric)
        guard !metric.isArchived else { return }
        scheduleReminder(for: metric)
        scheduleStreakAlert(for: metric)
    }
}

// MARK: - Countdown Completion

extension NotificationService {
    private static let countdownPrefix = "countdown-"

    /// Whether a delivered notification is a countdown's "time's up" alert,
    /// so the responder can show it even while the app is in the foreground.
    static func isCountdownNotification(id: String) -> Bool {
        id.hasPrefix(countdownPrefix)
    }

    /// Fires an alert when a running countdown reaches zero. Skipped if the
    /// target is already in the past (the timer is reconciled instead).
    static func scheduleCountdownCompletion(for metric: Metric, endsAt: Date) {
        guard let stableID = metric.stableID else { return }
        let remaining = endsAt.timeIntervalSinceNow
        guard remaining > 0 else { return }
        let request = UNNotificationRequest(
            identifier: countdownID(stableID),
            content: countdownContent(for: metric),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelCountdown(for metric: Metric) {
        guard let stableID = metric.stableID else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(
                withIdentifiers: [countdownID(stableID)]
            )
    }

    private static func scheduleRunningCountdown(for metric: Metric) {
        guard let session = SessionService.activeSession(for: metric),
              let end = session.countdownInterval?.upperBound
        else { return }
        scheduleCountdownCompletion(for: metric, endsAt: end)
    }

    private static func countdownID(_ stableID: UUID) -> String {
        "\(countdownPrefix)\(stableID.uuidString)"
    }

    private static func countdownContent(
        for metric: Metric
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(metric.name) timer finished"
        content.body = "Your countdown reached zero."
        // Honors the user's sound toggle; the banner still shows when muted.
        content.sound = CompletionAlertSettings.soundEnabled ? .default : nil
        return content
    }
}

// MARK: - Scheduling

extension NotificationService {
    /// Schedules the metric's daily reminder(s): the fixed times still ahead
    /// today, or — for a random window — that many seeded random pings, falling
    /// through to the next goal day once today's are spent. Up to
    /// `ReminderSchedule.maxPerDay` one-shots, each rescheduled on the next
    /// launch or log.
    private static func scheduleReminder(
        for metric: Metric
    ) {
        guard let schedule = metric.reminderSchedule,
              let stableID = metric.stableID,
              !hasLoggedToday(metric)
        else { return }
        let dates = ReminderPlanner.nextFireDates(
            for: schedule,
            seed: stableID.stableSeed,
            excludedWeekdays: metric.excludedWeekdaySet,
            now: .now
        )
        scheduleReminders(dates, for: metric, stableID: stableID)
    }

    private static func scheduleReminders(
        _ dates: [Date],
        for metric: Metric,
        stableID: UUID
    ) {
        let content = reminderContent(for: metric)
        for (index, date) in dates.enumerated() {
            let trigger = calendarTrigger(for: date)
            schedule(id: reminderID(stableID, index), content: content, trigger: trigger)
        }
    }

    private static func scheduleStreakAlert(
        for metric: Metric
    ) {
        guard let time = metric.streakAlertTime else { return }
        guard let stableID = metric.stableID else { return }
        guard !hasLoggedToday(metric) else { return }
        let streak = currentStreak(for: metric)
        guard streak > 0 else { return }
        guard let trigger = goalDayTrigger(
            for: time, excludedWeekdays: metric.excludedWeekdaySet
        ) else { return }

        let content = streakContent(
            for: metric, streak: streak
        )
        let id = "streak-\(stableID.uuidString)"
        schedule(id: id, content: content, trigger: trigger)
    }

    private static func cancelForMetric(_ metric: Metric) {
        guard let stableID = metric.stableID else { return }
        // The bare "reminder-<id>" clears any reminder scheduled by a
        // pre-multi-time build; the indexed ids clear the current ones.
        var ids = [
            "reminder-\(stableID.uuidString)",
            "streak-\(stableID.uuidString)"
        ]
        ids += (0 ..< ReminderSchedule.maxPerDay).map { reminderID(stableID, $0) }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Weekly Review

extension NotificationService {
    /// Request identifier of the weekly review notification; taps on it
    /// deep-link into the review sheet.
    static let weeklyReviewNotificationID = "weekly-review"

    private static func scheduleWeeklyReview(
        metrics: [Metric]
    ) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "weeklyReviewEnabled")
        else { return }
        let day = weeklyReviewDay(from: defaults)
        let hour = defaults.object(forKey: "weeklyReviewHour")
            as? Int ?? 9
        let minute = defaults.integer(
            forKey: "weeklyReviewMinute"
        )
        let content = weeklyReviewContent(metrics: metrics)
        let trigger = weeklyTrigger(
            weekday: day, hour: hour, minute: minute
        )
        schedule(id: weeklyReviewNotificationID, content: content, trigger: trigger)
    }

    private static func weeklyReviewDay(
        from defaults: UserDefaults
    ) -> Int {
        let stored = defaults.integer(forKey: "weeklyReviewDay")
        return stored > 0 ? stored : 2
    }

    private static func weeklyTrigger(
        weekday: Int,
        hour: Int,
        minute: Int
    ) -> UNCalendarNotificationTrigger {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = minute
        return UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
    }

    private static func weeklyReviewContent(
        metrics: [Metric]
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Review"
        content.body = weeklyReviewBody(metrics: metrics)
        content.sound = .default
        return content
    }

    private static func weeklyReviewBody(
        metrics: [Metric]
    ) -> String {
        let active = metrics.filter { hasRecentActivity($0) }
        let durationSessions = active
            .filter { $0.measurementType == .duration }
            .flatMap(\.sessions)
            .filter { !$0.isRunning }
        let durationTotals = SessionStatistics.dailyTotals(
            from: durationSessions
        )
        let weekDuration = SessionStatistics.lastSevenDaysTotal(
            from: durationTotals
        )
        let formatted = DurationFormatter.format(weekDuration)
        let sessionCount = active.flatMap(\.sessions)
            .filter { !$0.isRunning }.count
        return "You logged \(sessionCount) sessions "
            + "(\(formatted) tracked time) across "
            + "\(active.count) metrics this week."
    }

    private static func hasRecentActivity(
        _ metric: Metric
    ) -> Bool {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -6,
            to: Calendar.current.startOfDay(for: .now)
        ) else { return false }
        return metric.sessions.contains {
            !$0.isRunning && $0.startedAt >= cutoff
        }
    }
}

// MARK: - Content

extension NotificationService {
    private static func reminderContent(
        for metric: Metric
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let streak = currentStreak(for: metric)
        content.title = "Time to \(metric.name.lowercased())"
        content.body = streak > 0
            ? "Keep your \(streak)-day streak going!"
            : "Start building your streak today."
        content.sound = .default
        return content
    }

    private static func streakContent(
        for metric: Metric,
        streak: Int
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "\(metric.name) streak at risk"
        content.body = "Your \(streak)-day streak ends today "
            + "unless you log a session."
        content.sound = .default
        return content
    }
}

// MARK: - Helpers

extension NotificationService {
    private static func goalDayTrigger(
        for time: Date,
        excludedWeekdays: Set<Int>
    ) -> UNCalendarNotificationTrigger? {
        guard let date = nextGoalDate(
            for: time, excludedWeekdays: excludedWeekdays
        ) else { return nil }
        return calendarTrigger(for: date)
    }

    /// A one-shot trigger firing at the exact given date. Internal (not
    /// private) so the intention-question extension shares it.
    static func calendarTrigger(
        for date: Date
    ) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        return UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
    }

    private static func reminderID(_ stableID: UUID, _ index: Int) -> String {
        "reminder-\(stableID.uuidString)-\(index)"
    }

    private static func nextGoalDate(
        for time: Date,
        excludedWeekdays: Set<Int>
    ) -> Date? {
        let now = Date.now
        return (0 ... 7)
            .compactMap { goalCandidate(offset: $0, time: time) }
            .first { isGoalMoment($0, after: now, excludedWeekdays: excludedWeekdays) }
    }

    private static func isGoalMoment(
        _ date: Date,
        after now: Date,
        excludedWeekdays: Set<Int>
    ) -> Bool {
        guard date > now else { return false }
        return GoalDayRule.isGoalDay(
            on: date,
            excludedWeekdays: excludedWeekdays,
            calendar: Calendar.current
        )
    }

    private static func goalCandidate(
        offset: Int,
        time: Date
    ) -> Date? {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute], from: time)
        guard let day = calendar.date(
            byAdding: .day, value: offset,
            to: calendar.startOfDay(for: .now)
        ) else { return nil }
        return calendar.date(
            bySettingHour: comps.hour ?? 0,
            minute: comps.minute ?? 0,
            second: 0, of: day
        )
    }

    /// Internal (not private) so the intention-question extension shares it.
    static func schedule(
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNCalendarNotificationTrigger
    ) {
        let request = UNNotificationRequest(
            identifier: id, content: content, trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func hasLoggedToday(
        _ metric: Metric
    ) -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return metric.sessions.contains { session in
            !session.isRunning
                && session.startedAt >= today
        }
    }

    private static func currentStreak(
        for metric: Metric
    ) -> Int {
        let sessions = metric.sessions.filter { !$0.isRunning }
        let totals = SessionStatistics.dailyTotals(
            from: sessions
        )
        return SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: metric.excludedWeekdaySet
        )
    }
}
#endif
