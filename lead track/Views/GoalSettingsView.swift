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
    @State private var reminderSchedule: ReminderSchedule
    @State private var hasStreakAlert: Bool
    @State private var streakAlertTime: Date
    @State private var seasonWeeks: Int
    @State private var seasonNote: String
    @State private var expectsDaily: Bool
    @State private var saveTrigger = false

    /// `prefillWeeklyGoal` (in the metric's native unit) pre-enables the
    /// weekly goal with that value — how a promoted intention's target
    /// arrives — without touching the metric until Save.
    init(metric: Metric, prefillWeeklyGoal: Double? = nil) {
        self.metric = metric
        let weekly = prefillWeeklyGoal ?? metric.weeklyGoal
        _hasDailyGoal = State(initialValue: metric.dailyGoal != nil)
        _excludedWeekdays = State(initialValue: Set(metric.excludedWeekdays))
        _dailyGoalValue = State(
            initialValue: GoalUnit.daily(metric.measurementType)
                .display(fromStored: metric.dailyGoal)
        )
        _hasWeeklyGoal = State(
            initialValue: weekly != nil
        )
        _weeklyGoalValue = State(
            initialValue: GoalUnit.weekly(metric.measurementType)
                .display(fromStored: weekly)
        )
        let reminder = metric.reminderSchedule
        _hasReminder = State(initialValue: reminder != nil)
        _reminderSchedule = State(
            initialValue: reminder ?? .makeDefault()
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
        _expectsDaily = State(initialValue: metric.binaryGoalRetiredAt == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                if metric.measurementType.tracksQuantity {
                    dailyGoalSection
                    weeklyGoalSection
                    seasonSection
                } else {
                    binaryExpectationSection
                    restDaysSection
                    seasonSection
                }
                reminderSection
                streakAlertSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!goalsAreValid)
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

    /// The binary habit's target made explicit and releasable: on, showing
    /// up counts toward the day's rings; off, the habit keeps its card and
    /// history but carries no daily expectation — the binary form of a
    /// retired goal.
    private var binaryExpectationSection: some View {
        Section {
            Toggle("Expect It Daily", isOn: $expectsDaily)
        } footer: {
            Text("When off, the habit keeps its card and history but no longer counts toward the day's rings.")
        }
    }

    /// Binary metrics have no amount to set, so their "goal" is simply showing
    /// up each non-rest day — this section configures just that. Rest days
    /// stay editable even when the expectation is off: they keep protecting
    /// the logged-day streak.
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

    /// Whether a season applies to what's currently configured: an amount
    /// goal for quantity metrics, the live show-up expectation for binary.
    private var hasSeasonTarget: Bool {
        metric.measurementType.tracksQuantity
            ? hasDailyGoal || hasWeeklyGoal
            : expectsDaily
    }

    /// Every goal is an experiment with an end date: the season's length and
    /// what it is for. Shown only while a target is on — no target, no
    /// season.
    @ViewBuilder
    private var seasonSection: some View {
        if hasSeasonTarget {
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
        Section(footer: reminderFooter) {
            Toggle("Daily Reminder", isOn: $hasReminder)
            if hasReminder {
                ReminderScheduleEditor(schedule: $reminderSchedule)
            }
        }
    }

    private var reminderFooter: some View {
        Text(reminderFooterText)
    }

    private var reminderFooterText: String {
        let base = "Only notifies if you haven't logged yet."
        guard hasReminder, reminderSchedule.mode == .random else { return base }
        return "Pings land at random times inside your window. " + base
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

    /// An enabled amount goal must be a positive number before Save unlocks:
    /// the field's `.number` format accepts zero and negatives, and a
    /// The form's state as the shared draft whose `apply(to:)` owns the
    /// target and season rules (see `GoalSettingsDraft` — the rules are
    /// overlay-tested there, so this view stays a thin binding layer).
    private var draft: GoalSettingsDraft {
        GoalSettingsDraft(
            hasDailyGoal: hasDailyGoal,
            dailyGoalValue: dailyGoalValue,
            hasWeeklyGoal: hasWeeklyGoal,
            weeklyGoalValue: weeklyGoalValue,
            excludedWeekdays: excludedWeekdays,
            expectsDaily: expectsDaily,
            seasonWeeks: seasonWeeks,
            seasonNote: seasonNote
        )
    }

    private var goalsAreValid: Bool {
        draft.isValid(for: metric.measurementType)
    }

    private func save() {
        draft.apply(to: metric)
        metric.applyReminderSchedule(hasReminder ? reminderSchedule : nil)
        metric.streakAlertTime = hasStreakAlert ? streakAlertTime : nil
        NotificationService.rescheduleMetric(metric)
        saveTrigger.toggle()
        dismiss()
    }

    private static func defaultTime(hour: Int) -> Date {
        Calendar.current.date(
            from: DateComponents(hour: hour, minute: 0)
        ) ?? .now
    }
}
