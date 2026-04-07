import SwiftUI

struct WeeklyReviewSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weeklyReviewEnabled") private var isEnabled = false
    @AppStorage("weeklyReviewDay") private var day = 2
    @AppStorage("weeklyReviewHour") private var hour = 9
    @AppStorage("weeklyReviewMinute") private var minute = 0

    private let weekdays = Calendar.current.weekdaySymbols

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Weekly Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
                hour = components.hour ?? 9
                minute = components.minute ?? 0
            }
        )
    }
}
