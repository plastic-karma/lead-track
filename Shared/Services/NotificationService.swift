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
        for metric in metrics {
            scheduleReminder(for: metric)
            scheduleStreakAlert(for: metric)
        }
        scheduleWeeklyReview(metrics: metrics)
    }

    static func rescheduleMetric(
        _ metric: Metric
    ) {
        cancelForMetric(metric)
        scheduleReminder(for: metric)
        scheduleStreakAlert(for: metric)
    }
}

// MARK: - Scheduling

extension NotificationService {
    private static func scheduleReminder(
        for metric: Metric
    ) {
        guard let time = metric.reminderTime else { return }
        guard let stableID = metric.stableID else { return }
        guard !hasLoggedToday(metric) else { return }

        let content = reminderContent(for: metric)
        let trigger = dailyTrigger(for: time)
        let id = "reminder-\(stableID.uuidString)"
        schedule(id: id, content: content, trigger: trigger)
    }

    private static func scheduleStreakAlert(
        for metric: Metric
    ) {
        guard let time = metric.streakAlertTime else { return }
        guard let stableID = metric.stableID else { return }
        guard !hasLoggedToday(metric) else { return }
        let streak = currentStreak(for: metric)
        guard streak > 0 else { return }

        let content = streakContent(
            for: metric, streak: streak
        )
        let trigger = dailyTrigger(for: time)
        let id = "streak-\(stableID.uuidString)"
        schedule(id: id, content: content, trigger: trigger)
    }

    private static func cancelForMetric(_ metric: Metric) {
        guard let stableID = metric.stableID else { return }
        let ids = [
            "reminder-\(stableID.uuidString)",
            "streak-\(stableID.uuidString)"
        ]
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
    }
}

// MARK: - Weekly Review

extension NotificationService {
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
        schedule(id: "weekly-review", content: content, trigger: trigger)
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
    private static func dailyTrigger(
        for time: Date
    ) -> UNCalendarNotificationTrigger {
        let components = Calendar.current.dateComponents(
            [.hour, .minute], from: time
        )
        return UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
    }

    private static func schedule(
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
        return SessionStatistics.currentStreak(from: totals)
    }
}
#endif
