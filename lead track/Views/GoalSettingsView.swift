import SwiftUI

struct GoalSettingsView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss

    @State private var hasDailyGoal: Bool
    @State private var dailyGoalValue: Double
    @State private var hasWeeklyGoal: Bool
    @State private var weeklyGoalValue: Double
    @State private var hasReminder: Bool
    @State private var reminderTime: Date
    @State private var hasStreakAlert: Bool
    @State private var streakAlertTime: Date

    init(metric: Metric) {
        self.metric = metric
        let isCount = metric.measurementType == .count
        _hasDailyGoal = State(
            initialValue: metric.dailyGoal != nil
        )
        _dailyGoalValue = State(
            initialValue: isCount
                ? (metric.dailyGoal ?? 10)
                : (metric.dailyGoal ?? 1800) / 60
        )
        _hasWeeklyGoal = State(
            initialValue: metric.weeklyGoal != nil
        )
        _weeklyGoalValue = State(
            initialValue: isCount
                ? (metric.weeklyGoal ?? 50)
                : (metric.weeklyGoal ?? 18000) / 3600
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
        let unit = metric.measurementType == .count
            ? (metric.unit ?? "count") : "min"
        let step: Double = metric.measurementType == .count ? 1 : 5
        return goalField(
            value: $dailyGoalValue,
            unit: unit,
            suffix: "/ day",
            step: step
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
        let isCount = metric.measurementType == .count
        let unit = isCount ? (metric.unit ?? "count") : "h"
        let step: Double = isCount ? 5 : 0.5
        return goalField(
            value: $weeklyGoalValue,
            unit: unit,
            suffix: "/ week",
            step: step
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
    private func goalField(
        value: Binding<Double>,
        unit: String,
        suffix: String,
        step: Double
    ) -> some View {
        HStack {
            TextField(
                unit,
                value: value,
                format: .number
            )
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
            .frame(width: 80)
            Text("\(unit) \(suffix)")
                .foregroundStyle(.secondary)
            Spacer()
            Stepper(
                "",
                value: value,
                in: step ... .infinity,
                step: step
            )
            .labelsHidden()
        }
    }

    private func save() {
        let isCount = metric.measurementType == .count
        metric.dailyGoal = hasDailyGoal
            ? (isCount ? dailyGoalValue : dailyGoalValue * 60)
            : nil
        metric.weeklyGoal = hasWeeklyGoal
            ? (isCount ? weeklyGoalValue : weeklyGoalValue * 3600)
            : nil
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
