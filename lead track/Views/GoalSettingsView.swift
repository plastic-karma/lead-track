import SwiftUI

struct GoalSettingsView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss

    @State private var hasDailyGoal: Bool
    @State private var dailyMinutes: Double
    @State private var hasWeeklyGoal: Bool
    @State private var weeklyHours: Double
    @State private var hasReminder: Bool
    @State private var reminderTime: Date
    @State private var hasStreakAlert: Bool
    @State private var streakAlertTime: Date

    init(metric: Metric) {
        self.metric = metric
        _hasDailyGoal = State(
            initialValue: metric.dailyGoal != nil
        )
        _dailyMinutes = State(
            initialValue: (metric.dailyGoal ?? 1800) / 60
        )
        _hasWeeklyGoal = State(
            initialValue: metric.weeklyGoal != nil
        )
        _weeklyHours = State(
            initialValue: (metric.weeklyGoal ?? 18000) / 3600
        )
        _hasReminder = State(
            initialValue: metric.reminderTime != nil
        )
        _reminderTime = State(
            initialValue: metric.reminderTime ?? Self.defaultTime(hour: 9)
        )
        _hasStreakAlert = State(
            initialValue: metric.streakAlertTime != nil
        )
        _streakAlertTime = State(
            initialValue: metric.streakAlertTime ?? Self.defaultTime(hour: 20)
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                dailyGoalSection
                weeklyGoalSection
                reminderSection
                streakAlertSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Goal Sections

extension GoalSettingsView {
    private var dailyGoalSection: some View {
        Section {
            Toggle("Daily Goal", isOn: $hasDailyGoal)
            if hasDailyGoal {
                dailyGoalPicker
            }
        }
    }

    private var dailyGoalPicker: some View {
        Stepper(
            "\(Int(dailyMinutes)) min / day",
            value: $dailyMinutes,
            in: 5 ... 480,
            step: 5
        )
    }

    private var weeklyGoalSection: some View {
        Section {
            Toggle("Weekly Goal", isOn: $hasWeeklyGoal)
            if hasWeeklyGoal {
                weeklyGoalPicker
            }
        }
    }

    private var weeklyGoalPicker: some View {
        Stepper(
            formatWeeklyLabel(),
            value: $weeklyHours,
            in: 0.5 ... 80,
            step: 0.5
        )
    }
}

// MARK: - Reminder Sections

extension GoalSettingsView {
    private var reminderSection: some View {
        Section(footer: Text(
            "Only notifies if you haven't logged yet."
        )) {
            Toggle("Daily Reminder", isOn: $hasReminder)
            if hasReminder {
                DatePicker(
                    "Time",
                    selection: $reminderTime,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }

    private var streakAlertSection: some View {
        Section(footer: Text(
            "Warns you before your streak breaks."
        )) {
            Toggle("Streak at Risk Alert", isOn: $hasStreakAlert)
            if hasStreakAlert {
                DatePicker(
                    "Time",
                    selection: $streakAlertTime,
                    displayedComponents: .hourAndMinute
                )
            }
        }
    }
}

// MARK: - Helpers

extension GoalSettingsView {
    private func formatWeeklyLabel() -> String {
        if weeklyHours.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weeklyHours))h / week"
        }
        let mins = Int(weeklyHours * 60) % 60
        return "\(Int(weeklyHours))h \(mins)m / week"
    }

    private func save() {
        metric.dailyGoal = hasDailyGoal
            ? dailyMinutes * 60 : nil
        metric.weeklyGoal = hasWeeklyGoal
            ? weeklyHours * 3600 : nil
        metric.reminderTime = hasReminder
            ? reminderTime : nil
        metric.streakAlertTime = hasStreakAlert
            ? streakAlertTime : nil
        NotificationService.rescheduleMetric(metric)
        dismiss()
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(hour: hour, minute: 0)
        ) ?? .now
    }
}
