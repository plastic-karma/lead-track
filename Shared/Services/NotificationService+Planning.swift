import Foundation

// The pure half of `NotificationService`: which moments to arm and what the
// banners say. No UserNotifications dependency, so it compiles — and is
// unit-tested — on the Linux overlay too.

// MARK: - Pure Planning

extension NotificationService {
    /// The reminder moments to arm for the metric — the next eligible fires
    /// from `ReminderPlanner`, falling through to the next goal day once
    /// today is logged. Logging today must never unarm tomorrow.
    static func reminderFireDates(
        for metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Date] {
        guard let schedule = metric.reminderSchedule,
              let stableID = metric.stableID
        else { return [] }
        return ReminderPlanner.nextFireDates(
            for: schedule,
            seed: stableID.stableSeed,
            excludedWeekdays: metric.excludedWeekdaySet,
            now: now,
            calendar: calendar,
            skippingToday: hasLoggedToday(metric, now: now, calendar: calendar)
        )
    }

    /// When the streak-at-risk alert should fire: the metric's alert time on
    /// the next goal day — skipping today once it is already logged, so the
    /// alert re-arms for tomorrow instead of going silent.
    static func streakAlertFireDate(
        for metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date? {
        guard let time = metric.streakAlertTime else { return nil }
        return ReminderPlanner.nextGoalMoment(
            at: time,
            excludedWeekdays: metric.excludedWeekdaySet,
            now: now,
            calendar: calendar,
            skippingToday: hasLoggedToday(metric, now: now, calendar: calendar)
        )
    }

    /// Whether the metric has a completed session on `now`'s day.
    static func hasLoggedToday(
        _ metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        let today = calendar.startOfDay(for: now)
        return metric.sessions.contains { !$0.isRunning && $0.startedAt >= today }
    }

    /// The metric's live streak, from its completed sessions.
    static func currentStreak(for metric: Metric) -> Int {
        let totals = SessionStatistics.dailyTotals(
            from: metric.sessions.filter { !$0.isRunning }
        )
        return SessionStatistics.currentStreak(
            from: totals, excludedWeekdays: metric.excludedWeekdaySet
        )
    }
}

// MARK: - Pure Copy

extension NotificationService {
    /// Banner copy for the daily reminder. Discreet mode — the app lock is
    /// on — keeps metric names and streak counts off the lock screen.
    static func reminderCopy(
        name: String,
        streak: Int,
        discreet: Bool
    ) -> (title: String, body: String) {
        guard !discreet else {
            return (title: "Time to check in", body: "Your daily check-in is waiting.")
        }
        return (
            title: "Time to \(name.lowercased())",
            body: streak > 0
                ? "Keep your \(streak)-day streak going!"
                : "Start building your streak today."
        )
    }

    /// Banner copy for the streak-at-risk alert.
    static func streakAlertCopy(
        name: String,
        streak: Int,
        discreet: Bool
    ) -> (title: String, body: String) {
        guard !discreet else {
            return (title: "Streak at risk", body: "Log a session today to keep your streak.")
        }
        return (
            title: "\(name) streak at risk",
            body: "Your \(streak)-day streak ends today unless you log a session."
        )
    }

    /// Banner copy for a countdown reaching zero.
    static func countdownCopy(name: String, discreet: Bool) -> (title: String, body: String) {
        (
            title: discreet ? "Timer finished" : "\(name) timer finished",
            body: "Your countdown reached zero."
        )
    }

    /// Banner copy for an intention's daily question — the title and question
    /// are the user's own words, so discreet mode replaces both.
    static func questionCopy(
        title: String,
        question: String,
        discreet: Bool
    ) -> (title: String, body: String) {
        discreet
            ? (title: "Daily check-in", body: "Your intention has a question for you.")
            : (title: title, body: question)
    }
}
