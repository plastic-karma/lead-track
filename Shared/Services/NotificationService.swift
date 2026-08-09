import Foundation
#if canImport(SwiftData)
import SwiftData
#endif
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Schedules the app's local notifications: daily reminders, streak-at-risk
/// alerts, countdown completions, periodic reviews, and intention questions.
/// The pure half — which moments to arm, what the banners say — lives in
/// `NotificationService+Planning.swift` and the review schedule settings,
/// both of which compile everywhere for Linux test coverage. The
/// trigger-wrapping shell below needs UserNotifications.
enum NotificationService {}

#if canImport(UserNotifications)

// MARK: - Entry Points

extension NotificationService {
    /// Fire-and-forget by design — the app degrades gracefully when denied —
    /// but the outcome is logged so "reminders never fire" stays diagnosable
    /// in a sysdiagnose.
    static func requestPermission() {
        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
                if !granted {
                    NotifyLog.notice("notification permission not granted")
                }
            } catch {
                NotifyLog.error("requestAuthorization failed: \(error.localizedDescription)")
            }
        }
    }

    /// The wipe-and-rebuild sweep behind every foreground pass. Async so the
    /// call site can keep it out of the scene-activation turn, and yielding
    /// between metrics so UI work interleaves with the full-history streak
    /// math instead of stalling behind one long pass.
    static func rescheduleAll(container: ModelContainer) async {
        let context = ModelContext(container)
        let metrics: [Metric]
        do {
            metrics = try context.fetch(FetchDescriptor<Metric>())
        } catch {
            NotifyLog.error("rescheduleAll metric fetch failed: \(error.localizedDescription)")
            return
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        // Archived metrics rest silently — no reminders, no streak nudges,
        // and no countdown alerts.
        for metric in metrics.unarchived {
            scheduleNotifications(for: metric)
            scheduleRunningCountdown(for: metric)
            await Task.yield()
        }
        scheduleReviewNotifications()
        scheduleAllIntentionQuestions(in: context)
    }

    static func rescheduleMetric(_ metric: Metric) {
        cancelForMetric(metric)
        guard !metric.isArchived else { return }
        scheduleNotifications(for: metric)
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
        add(UNNotificationRequest(
            identifier: countdownID(stableID),
            content: countdownContent(for: metric),
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        ))
    }

    static func cancelCountdown(for metric: Metric) {
        guard let stableID = metric.stableID else { return }
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [countdownID(stableID)])
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

    private static func countdownContent(for metric: Metric) -> UNMutableNotificationContent {
        let content = makeContent(
            countdownCopy(name: metric.name, discreet: NotificationPrivacy.isDiscreet())
        )
        // Honors the user's sound toggle; the banner still shows when muted.
        content.sound = CompletionAlertSettings.soundEnabled ? .default : nil
        return content
    }
}

// MARK: - Scheduling

extension NotificationService {
    /// One shared streak feeds both banners — computing it walks the metric's
    /// whole session history, so it runs once per metric per sweep.
    private static func scheduleNotifications(for metric: Metric) {
        let streak = currentStreak(for: metric)
        let discreet = NotificationPrivacy.isDiscreet()
        scheduleReminder(for: metric, streak: streak, discreet: discreet)
        scheduleStreakAlert(for: metric, streak: streak, discreet: discreet)
    }

    /// Schedules the metric's daily reminder(s): the fixed times still ahead
    /// today, or — for a random window — that many seeded random pings,
    /// falling through to the next goal day once today's are spent or today
    /// is already logged. Up to `ReminderSchedule.maxPerDay` one-shots, each
    /// rescheduled on the next launch or log.
    private static func scheduleReminder(
        for metric: Metric,
        streak: Int,
        discreet: Bool
    ) {
        guard let stableID = metric.stableID else { return }
        let dates = reminderFireDates(for: metric)
        guard !dates.isEmpty else { return }
        let copy = reminderCopy(name: metric.name, streak: streak, discreet: discreet)
        for (index, date) in dates.enumerated() {
            schedule(
                id: reminderID(stableID, index),
                content: makeContent(copy),
                trigger: calendarTrigger(for: date)
            )
        }
    }

    private static func scheduleStreakAlert(
        for metric: Metric,
        streak: Int,
        discreet: Bool
    ) {
        guard streak > 0,
              let stableID = metric.stableID,
              let date = streakAlertFireDate(for: metric)
        else { return }
        schedule(
            id: "streak-\(stableID.uuidString)",
            content: makeContent(
                streakAlertCopy(name: metric.name, streak: streak, discreet: discreet)
            ),
            trigger: calendarTrigger(for: date)
        )
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

// MARK: - Review Schedule

extension NotificationService {
    /// The old ID remains recognizable so a notification delivered by the
    /// previous build still deep-links correctly after an update.
    private static let legacyWeeklyReviewNotificationID = "weekly-review"

    static func isReviewNotification(id: String) -> Bool {
        id == legacyWeeklyReviewNotificationID || id.hasPrefix("review-")
    }

    /// Re-arms (or clears) every planned review boundary after a settings edit.
    static func rescheduleReviewNotifications() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: reviewNotificationIDs)
        scheduleReviewNotifications()
    }

    /// Calendar triggers are one-shot because arbitrary day/month intervals
    /// cannot repeat without drifting through DST. Several future boundaries
    /// keep the cycle alive when a notification is ignored; every foreground
    /// sweep replenishes the queue.
    private static func scheduleReviewNotifications() {
        guard WeeklyReviewSettings.isEnabled() else { return }
        let dates = ReviewSchedule.fireDates(
            for: WeeklyReviewSettings.cycle(),
            hour: WeeklyReviewSettings.hour(),
            minute: WeeklyReviewSettings.minute()
        )
        for (index, date) in dates.enumerated() {
            schedule(
                id: reviewNotificationID(index),
                content: makeContent((
                    title: "Review Ready",
                    body: "A new review period has started — take a moment to look back."
                )),
                trigger: calendarTrigger(for: date)
            )
        }
    }

    private static var reviewNotificationIDs: [String] {
        [legacyWeeklyReviewNotificationID]
            + (0 ..< ReviewSchedule.notificationCount).map { reviewNotificationID($0) }
    }

    private static func reviewNotificationID(_ index: Int) -> String {
        "review-\(index)"
    }
}

// MARK: - Helpers

extension NotificationService {
    /// A one-shot trigger firing at the exact given date. Internal (not
    /// private) so the intention-question extension shares it.
    static func calendarTrigger(
        for date: Date,
        calendar: Calendar = .current
    ) -> UNCalendarNotificationTrigger {
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        return UNCalendarNotificationTrigger(
            dateMatching: components, repeats: false
        )
    }

    /// A sounded banner from a copy pair. Internal (not private) so the
    /// intention-question extension shares it.
    static func makeContent(
        _ copy: (title: String, body: String)
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        return content
    }

    /// Internal (not private) so the intention-question extension shares it.
    static func schedule(
        id: String,
        content: UNMutableNotificationContent,
        trigger: UNCalendarNotificationTrigger
    ) {
        add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// The async `add` with its error surfaced to the log — identifiers only,
    /// never content — instead of discarded.
    private static func add(_ request: UNNotificationRequest) {
        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                NotifyLog.error(
                    "add failed for \(request.identifier): \(error.localizedDescription)"
                )
            }
        }
    }

    private static func reminderID(_ stableID: UUID, _ index: Int) -> String {
        "reminder-\(stableID.uuidString)-\(index)"
    }
}
#endif
