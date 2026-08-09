import SwiftUI

struct WeeklyReviewSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeeklyReviewSettings.enabledKey) private var isEnabled = false
    @AppStorage(WeeklyReviewSettings.dayKey) private var day = WeeklyReviewSettings.defaultDay
    @AppStorage(WeeklyReviewSettings.hourKey) private var hour = WeeklyReviewSettings.defaultHour
    @AppStorage(WeeklyReviewSettings.minuteKey) private var minute = WeeklyReviewSettings.defaultMinute

    private let weekdays = Calendar.current.weekdaySymbols

    var body: some View {
        NavigationStack {
            form
                .navigationTitle("Weekly Review")
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
            Section(footer: Text(
                "Get a weekly summary of your progress."
            )) {
                Toggle(
                    "Weekly Review Notification",
                    isOn: $isEnabled
                )
                if isEnabled {
                    dayPicker
                    timePicker
                }
            }
        }
        // Re-arm the notification on every edit: waiting for the next
        // foreground pass could silently miss the chosen day entirely.
        .onChange(of: isEnabled) { reschedule() }
        .onChange(of: day) { reschedule() }
        .onChange(of: hour) { reschedule() }
        .onChange(of: minute) { reschedule() }
    }

    private func reschedule() {
        NotificationService.rescheduleWeeklyReview()
    }

    private var dayPicker: some View {
        Picker("Day", selection: $day) {
            ForEach(1 ... 7, id: \.self) { weekday in
                Text(weekdays[weekday - 1])
                    .tag(weekday)
            }
        }
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
                    from: DateComponents(
                        hour: hour, minute: minute
                    )
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
}
