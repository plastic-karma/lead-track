import SwiftUI

struct GoalSettingsView: View {
    let metric: Metric
    @Environment(\.dismiss) private var dismiss

    @State private var hasDailyGoal: Bool
    @State private var dailyGoalValue: Double
    @State private var excludedWeekdays: Set<Int>
    @State private var hasWeeklyGoal: Bool
    @State private var weeklyGoalValue: Double
    @State private var hasReminder: Bool
    @State private var reminderTime: Date
    @State private var hasStreakAlert: Bool
    @State private var streakAlertTime: Date
    @State private var seasonWeeks: Int
    @State private var seasonNote: String
    @State private var saveTrigger = false

    /// `prefillWeeklyGoal` (in the metric's native unit) pre-enables the
    /// weekly goal with that value — how a promoted intention's target
    /// arrives — without touching the metric until Save.
    init(metric: Metric, prefillWeeklyGoal: Double? = nil) {
        self.metric = metric
        let isCount = metric.measurementType == .count
        let weekly = prefillWeeklyGoal ?? metric.weeklyGoal
        _hasDailyGoal = State(initialValue: metric.dailyGoal != nil)
        _excludedWeekdays = State(initialValue: Set(metric.excludedWeekdays))
        _dailyGoalValue = State(
            initialValue: isCount
                ? (metric.dailyGoal ?? 10)
                : (metric.dailyGoal ?? 1800) / 60
        )
        _hasWeeklyGoal = State(
            initialValue: weekly != nil
        )
        _weeklyGoalValue = State(
            initialValue: isCount
                ? (weekly ?? 50)
                : (weekly ?? 18000) / 3600
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
        _seasonWeeks = State(
            initialValue: metric.goalSeasonWeeks ?? GoalSeason.defaultLengthWeeks
        )
        _seasonNote = State(initialValue: metric.goalSeasonNote)
    }

    var body: some View {
        NavigationStack {
            Form {
                if metric.measurementType.tracksQuantity {
                    dailyGoalSection
                    weeklyGoalSection
                    seasonSection
                } else {
                    restDaysSection
                }
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
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }
}

// MARK: - Goal Sections

extension GoalSettingsView {
    private var dailyGoalSection: some View {
        Section(footer: restDaysFooter) {
            Toggle("Daily Goal", isOn: $hasDailyGoal)
            if hasDailyGoal {
                dailyGoalPicker
                restDaysRow
            }
        }
    }

    private var restDaysRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rest Days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            WeekdaySelector(excludedWeekdays: $excludedWeekdays)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var restDaysFooter: some View {
        if hasDailyGoal {
            Text("Tap a day to make it a rest day. Rest days don't break your streak or send reminders.")
        }
    }

    /// Binary metrics have no amount to set, so their "goal" is simply showing
    /// up each non-rest day — this section configures just that.
    private var restDaysSection: some View {
        Section {
            restDaysRow
        } footer: {
            Text("Tap a day to make it a rest day. Rest days don't break your streak or send reminders.")
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

    /// Every goal is an experiment with an end date: the season's length and
    /// what it is for. Shown only while a goal is on — no goal, no season.
    @ViewBuilder
    private var seasonSection: some View {
        if hasDailyGoal || hasWeeklyGoal {
            Section {
                Picker("Length", selection: $seasonWeeks) {
                    ForEach(GoalSeason.lengthChoices, id: \.self) { weeks in
                        Text("\(weeks) weeks").tag(weeks)
                    }
                }
                TextField(
                    "What is this season for?",
                    text: $seasonNote,
                    axis: .vertical
                )
            } header: {
                Text("Season")
            } footer: {
                Text(
                    "Goals are experiments with an end date. When the season "
                        + "ends, the weekly review asks whether to renew, "
                        + "adjust, or retire the target."
                )
            }
        }
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
        let previousDaily = metric.dailyGoal
        let previousWeekly = metric.weeklyGoal
        if metric.measurementType.tracksQuantity {
            saveAmountGoals()
        } else {
            metric.dailyGoal = nil
            metric.weeklyGoal = nil
            metric.excludedWeekdays = excludedWeekdays.sorted()
        }
        saveSeason(previousDaily: previousDaily, previousWeekly: previousWeekly)
        metric.reminderTime = hasReminder ? reminderTime : nil
        metric.streakAlertTime = hasStreakAlert ? streakAlertTime : nil
        NotificationService.rescheduleMetric(metric)
        saveTrigger.toggle()
        dismiss()
    }

    /// Seasons ride every goal save: a goal present keeps (or starts) its
    /// season — so unseasoned legacy goals acquire one here, on their first
    /// edit — and both goals off ends it. Only an amount change re-stamps
    /// the start; reminder-only edits never reset the clock.
    private func saveSeason(previousDaily: TimeInterval?, previousWeekly: TimeInterval?) {
        guard metric.dailyGoal != nil || metric.weeklyGoal != nil else {
            GoalSeason.clearSeason(of: metric)
            return
        }
        metric.goalSeasonWeeks = seasonWeeks
        metric.goalSeasonNote = seasonNote.trimmingCharacters(in: .whitespacesAndNewlines)
        GoalSeason.stampOnSave(
            metric,
            amountsChanged: metric.dailyGoal != previousDaily || metric.weeklyGoal != previousWeekly
        )
    }

    private func saveAmountGoals() {
        let isCount = metric.measurementType == .count
        metric.dailyGoal = hasDailyGoal
            ? (isCount ? dailyGoalValue : dailyGoalValue * 60)
            : nil
        metric.excludedWeekdays = hasDailyGoal ? excludedWeekdays.sorted() : []
        metric.weeklyGoal = hasWeeklyGoal
            ? (isCount ? weeklyGoalValue : weeklyGoalValue * 3600)
            : nil
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(hour: hour, minute: 0)
        ) ?? .now
    }
}
