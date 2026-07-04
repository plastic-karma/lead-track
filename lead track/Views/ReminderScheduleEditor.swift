import SwiftUI

/// Editor for a metric's daily-reminder timing: either up to three fixed times
/// of day, or a count of pings dropped at random moments inside a daily window.
/// Renders a set of sibling `Form` rows inside the reminder section.
struct ReminderScheduleEditor: View {
    @Binding var schedule: ReminderSchedule

    var body: some View {
        modePicker
        if schedule.mode == .fixed {
            fixedTimesEditor
        } else {
            randomRangeEditor
        }
    }
}

// MARK: - Mode

extension ReminderScheduleEditor {
    private var modePicker: some View {
        Picker("Style", selection: $schedule.mode) {
            Text("Fixed times").tag(ReminderSchedule.Mode.fixed)
            Text("Random in range").tag(ReminderSchedule.Mode.random)
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Fixed Times

extension ReminderScheduleEditor {
    @ViewBuilder
    private var fixedTimesEditor: some View {
        ForEach(schedule.fixedTimes.indices, id: \.self) { index in
            fixedTimeRow(index)
        }
        if schedule.fixedTimes.count < ReminderSchedule.maxPerDay {
            Button(action: addFixedTime) {
                Label("Add a time", systemImage: "plus.circle")
            }
        }
    }

    private func fixedTimeRow(_ index: Int) -> some View {
        HStack {
            DatePicker(
                "Time \(index + 1)",
                selection: fixedTimeBinding(index),
                displayedComponents: .hourAndMinute
            )
            if schedule.fixedTimes.count > 1 {
                removeButton(index)
            }
        }
    }

    /// A binding to one fixed time; the array-index subscript isn't reachable
    /// through the projected `$schedule` binding, so build it by hand. Guards
    /// the index so a row torn down mid-delete can't read out of bounds.
    private func fixedTimeBinding(_ index: Int) -> Binding<Date> {
        Binding(
            get: {
                guard schedule.fixedTimes.indices.contains(index) else {
                    return ReminderSchedule.time(hour: 9)
                }
                return schedule.fixedTimes[index]
            },
            set: { newValue in
                guard schedule.fixedTimes.indices.contains(index) else { return }
                schedule.fixedTimes[index] = newValue
            }
        )
    }

    private func removeButton(_ index: Int) -> some View {
        Button(role: .destructive) {
            removeFixedTime(at: index)
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Remove time \(index + 1)")
    }
}

// MARK: - Random Range

extension ReminderScheduleEditor {
    @ViewBuilder
    private var randomRangeEditor: some View {
        DatePicker(
            "From", selection: $schedule.rangeStart, displayedComponents: .hourAndMinute
        )
        DatePicker(
            "To", selection: $schedule.rangeEnd, displayedComponents: .hourAndMinute
        )
        Stepper(
            "\(schedule.count) \(schedule.count == 1 ? "ping" : "pings") a day",
            value: $schedule.count,
            in: 1 ... ReminderSchedule.maxPerDay
        )
    }
}

// MARK: - Mutations

extension ReminderScheduleEditor {
    private func addFixedTime() {
        guard schedule.fixedTimes.count < ReminderSchedule.maxPerDay else { return }
        schedule.fixedTimes.append(nextSuggestedTime())
    }

    private func removeFixedTime(at index: Int) {
        guard schedule.fixedTimes.count > 1,
              schedule.fixedTimes.indices.contains(index)
        else { return }
        schedule.fixedTimes.remove(at: index)
    }

    /// An hour past the last time, so a freshly added row doesn't duplicate it.
    private func nextSuggestedTime() -> Date {
        guard let last = schedule.fixedTimes.last else {
            return ReminderSchedule.time(hour: 9)
        }
        return Calendar.current.date(byAdding: .hour, value: 1, to: last) ?? last
    }
}
