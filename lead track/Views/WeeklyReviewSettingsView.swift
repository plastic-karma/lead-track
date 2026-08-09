import SwiftUI

struct WeeklyReviewSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeeklyReviewSettings.enabledKey) private var isEnabled = false
    @AppStorage(WeeklyReviewSettings.cycleKey) private var cycle = WeeklyReviewSettings.defaultCycle
    @AppStorage(WeeklyReviewSettings.customUnitKey) private var customUnit =
        WeeklyReviewSettings.defaultCustomUnit
    @AppStorage(WeeklyReviewSettings.customIntervalKey) private var customInterval =
        WeeklyReviewSettings.defaultCustomInterval
    @AppStorage(WeeklyReviewSettings.customAnchorKey) private var customAnchor = 0.0
    @AppStorage(WeeklyReviewSettings.dayKey) private var day = WeeklyReviewSettings.defaultDay
    @AppStorage(WeeklyReviewSettings.hourKey) private var hour = WeeklyReviewSettings.defaultHour
    @AppStorage(WeeklyReviewSettings.minuteKey) private var minute = WeeklyReviewSettings.defaultMinute

    private let weekdays = Calendar.current.weekdaySymbols

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Review Schedule")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }

    private var form: some View {
        Form {
            Section {
                Toggle("Review Notifications", isOn: $isEnabled)
                if isEnabled {
                    cyclePicker
                    cycleOptions
                    timePicker
                }
            } footer: {
                Text(scheduleDescription)
            }
        }
        .onAppear { ensureCustomAnchor() }
        .onChange(of: isEnabled) {
            ensureCustomAnchor()
            reschedule()
        }
        .onChange(of: cycle) {
            if cycle == .custom {
                resetCustomAnchor()
            }
            reschedule()
        }
        .onChange(of: customUnit) {
            customInterval = min(customInterval, customUnit.maximumInterval)
            resetCustomAnchor()
            reschedule()
        }
        .onChange(of: customInterval) {
            resetCustomAnchor()
            reschedule()
        }
        .onChange(of: day) { reschedule() }
        .onChange(of: hour) { reschedule() }
        .onChange(of: minute) { reschedule() }
    }

    private var cyclePicker: some View {
        Picker("Cycle", selection: $cycle) {
            Text("Weekly").tag(ReviewCycleKind.weekly)
            Text("Monthly").tag(ReviewCycleKind.monthly)
            Text("Quarterly").tag(ReviewCycleKind.quarterly)
            Text("Yearly").tag(ReviewCycleKind.yearly)
            Text("Custom").tag(ReviewCycleKind.custom)
        }
    }

    @ViewBuilder
    private var cycleOptions: some View {
        switch cycle {
        case .weekly:
            dayPicker
        case .custom:
            customUnitPicker
            customIntervalStepper
        case .monthly, .quarterly, .yearly:
            EmptyView()
        }
    }

    private var dayPicker: some View {
        Picker("Period starts", selection: $day) {
            ForEach(1 ... 7, id: \.self) { weekday in
                Text(weekdays[weekday - 1])
                    .tag(weekday)
            }
        }
    }

    private var customUnitPicker: some View {
        Picker("Unit", selection: $customUnit) {
            Text("Days").tag(ReviewCycleUnit.days)
            Text("Months").tag(ReviewCycleUnit.months)
        }
        .pickerStyle(.segmented)
    }

    private var customIntervalStepper: some View {
        Stepper(
            value: $customInterval,
            in: 1 ... customUnit.maximumInterval
        ) {
            Text(customIntervalLabel)
        }
    }

    private var customIntervalLabel: String {
        let unit = customUnit == .days ? "day" : "month"
        let suffix = customInterval == 1 ? "" : "s"
        return "Every \(customInterval) \(unit)\(suffix)"
    }

    private var timePicker: some View {
        DatePicker(
            "Time",
            selection: timeBinding,
            displayedComponents: .hourAndMinute
        )
    }

    private var timeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(hour: hour, minute: minute)
                ) ?? .now
            },
            set: { newValue in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute], from: newValue
                )
                hour = components.hour ?? WeeklyReviewSettings.defaultHour
                minute = components.minute ?? WeeklyReviewSettings.defaultMinute
            }
        )
    }

    private var scheduleDescription: String {
        guard isEnabled else {
            return "Choose when LeadStone should prompt you to review your progress."
        }
        let next = ReviewSchedule.fireDates(
            for: WeeklyReviewSettings.cycle(),
            hour: hour,
            minute: minute,
            count: 1
        ).first
        guard let next else {
            return "Reviews arrive on the first day of each new period."
        }
        return "Next review: \(next.formatted(date: .abbreviated, time: .shortened)). "
            + "Reviews arrive on the first day of each new period."
    }

    private func ensureCustomAnchor() {
        guard cycle == .custom, customAnchor <= 0 else { return }
        resetCustomAnchor()
    }

    private func resetCustomAnchor() {
        guard cycle == .custom else { return }
        customAnchor = Calendar.current.startOfDay(for: .now).timeIntervalSinceReferenceDate
    }

    private func reschedule() {
        NotificationService.rescheduleReviewNotifications()
    }
}
