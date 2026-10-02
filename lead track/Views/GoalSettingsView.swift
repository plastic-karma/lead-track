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
                    GoalDailySettingsSection(
                        hasDailyGoal: $hasDailyGoal, value: $dailyGoalValue,
                        excludedWeekdays: $excludedWeekdays,
                        isCount: metric.measurementType == .count, unit: metric.unit
                    )
                    GoalWeeklySettingsSection(
                        hasWeeklyGoal: $hasWeeklyGoal, value: $weeklyGoalValue,
                        isCount: metric.measurementType == .count, unit: metric.unit
                    )
                } else {
                    GoalBinaryExpectationSection(expectsDaily: $expectsDaily)
                    Section {
                        GoalRestDaysRow(excludedWeekdays: $excludedWeekdays)
                    } footer: {
                        Text("Tap a day to make it a rest day. Rest days don't break your streak or send reminders.")
                    }
                }
                if hasSeasonTarget {
                    GoalSeasonSettingsSection(weeks: $seasonWeeks, note: $seasonNote)
                }
                GoalReminderSettingsSection(hasReminder: $hasReminder, schedule: $reminderSchedule)
                GoalStreakAlertSettingsSection(hasAlert: $hasStreakAlert, time: $streakAlertTime)
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
    /// Whether a season applies to what's currently configured: an amount
    /// goal for quantity metrics, the live show-up expectation for binary.
    private var hasSeasonTarget: Bool {
        metric.measurementType.tracksQuantity
            ? hasDailyGoal || hasWeeklyGoal
            : expectsDaily
    }
}

// MARK: - Helpers

extension GoalSettingsView {
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

private struct GoalRestDaysRow: View {
    @Binding var excludedWeekdays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rest Days")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            WeekdaySelector(excludedWeekdays: $excludedWeekdays)
        }
        .padding(.vertical, 4)
    }
}

private struct GoalDailySettingsSection: View {
    @Binding var hasDailyGoal: Bool
    @Binding var value: Double
    @Binding var excludedWeekdays: Set<Int>
    let isCount: Bool
    let unit: String?

    var body: some View {
        Section {
            Toggle("Daily Goal", isOn: $hasDailyGoal)
            if hasDailyGoal {
                GoalAmountField(
                    value: $value,
                    unit: isCount ? (unit ?? "count") : "min",
                    suffix: "/ day",
                    step: isCount ? 1 : 5
                )
                GoalRestDaysRow(excludedWeekdays: $excludedWeekdays)
            }
        } footer: {
            if hasDailyGoal {
                Text("Tap a day to make it a rest day. Rest days don't break your streak or send reminders.")
            }
        }
    }
}

private struct GoalWeeklySettingsSection: View {
    @Binding var hasWeeklyGoal: Bool
    @Binding var value: Double
    let isCount: Bool
    let unit: String?

    var body: some View {
        Section {
            Toggle("Weekly Goal", isOn: $hasWeeklyGoal)
            if hasWeeklyGoal {
                GoalAmountField(
                    value: $value,
                    unit: isCount ? (unit ?? "count") : "h",
                    suffix: "/ week",
                    step: isCount ? 5 : 0.5
                )
            }
        }
    }
}

private struct GoalBinaryExpectationSection: View {
    @Binding var expectsDaily: Bool

    var body: some View {
        Section {
            Toggle("Expect It Daily", isOn: $expectsDaily)
        } footer: {
            Text("When off, the habit keeps its card and history but no longer counts toward the day's rings.")
        }
    }
}

private struct GoalSeasonSettingsSection: View {
    @Binding var weeks: Int
    @Binding var note: String

    var body: some View {
        Section {
            Picker("Length", selection: $weeks) {
                ForEach(GoalSeason.lengthChoices, id: \.self) { length in
                    Text("\(length) weeks").tag(length)
                }
            }
            TextField("What is this season for?", text: $note, axis: .vertical)
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

private struct GoalReminderSettingsSection: View {
    @Binding var hasReminder: Bool
    @Binding var schedule: ReminderSchedule

    var body: some View {
        Section {
            Toggle("Daily Reminder", isOn: $hasReminder)
            if hasReminder {
                ReminderScheduleEditor(schedule: $schedule)
            }
        } footer: {
            Text(hasReminder && schedule.mode == .random
                ? "Pings land at random times inside your window. Only notifies if you haven't logged yet."
                : "Only notifies if you haven't logged yet.")
        }
    }
}

private struct GoalStreakAlertSettingsSection: View {
    @Binding var hasAlert: Bool
    @Binding var time: Date

    var body: some View {
        Section {
            Toggle("Streak at Risk Alert", isOn: $hasAlert)
            if hasAlert {
                DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
            }
        } footer: {
            Text("Warns you before your streak breaks.")
        }
    }
}

private struct GoalAmountField: View {
    @ScaledMetric(relativeTo: .body) private var fieldWidth: CGFloat = 80
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var value: Double
    let unit: String
    let suffix: String
    let step: Double

    var body: some View {
        layout {
            TextField(unit, value: $value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(.roundedBorder)
                .frame(minWidth: 80, maxWidth: fieldWidth)
                .accessibilityLabel("Goal amount, \(unit) \(suffix)")
            Text("\(unit) \(suffix)")
                .foregroundStyle(.secondary)
            Stepper("\(unit) \(suffix)", value: $value, in: step ... .infinity, step: step)
                .labelsHidden()
                .accessibilityValue(value.formatted())
        }
    }

    private var layout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout())
    }
}
