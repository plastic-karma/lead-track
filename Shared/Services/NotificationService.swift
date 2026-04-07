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
        guard !hasLoggedToday(metric) else { return }

        let content = reminderContent(for: metric)
        let trigger = dailyTrigger(for: time)
        let id = "reminder-\(metric.name)"
        schedule(id: id, content: content, trigger: trigger)
    }

    private static func scheduleStreakAlert(
        for metric: Metric
    ) {
        guard let time = metric.streakAlertTime else { return }
        guard !hasLoggedToday(metric) else { return }
        let streak = currentStreak(for: metric)
        guard streak > 0 else { return }

        let content = streakContent(
            for: metric, streak: streak
        )
        let trigger = dailyTrigger(for: time)
        let id = "streak-\(metric.name)"
        schedule(id: id, content: content, trigger: trigger)
    }

    private static func cancelForMetric(_ metric: Metric) {
        let ids = [
            "reminder-\(metric.name)",
            "streak-\(metric.name)"
        ]
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: ids)
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
