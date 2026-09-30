import SwiftUI

/// Editor for a metric's daily-reminder timing: either up to three fixed times
/// of day, or a count of pings dropped at random moments inside a daily window.
/// Renders a set of sibling `Form` rows inside the reminder section.
struct ReminderScheduleEditor: View {
    @Binding var schedule: ReminderSchedule

    var body: some View {
        Picker("Style", selection: $schedule.mode) {
            Text("Fixed times").tag(ReminderSchedule.Mode.fixed)
            Text("Random in range").tag(ReminderSchedule.Mode.random)
        }
        .pickerStyle(.segmented)
        if schedule.mode == .fixed {
            ReminderFixedTimesEditor(times: $schedule.fixedTimes)
        } else {
            ReminderRandomRangeEditor(
                start: $schedule.rangeStart, end: $schedule.rangeEnd, count: $schedule.count
            )
        }
    }
}

private struct ReminderFixedTimesEditor: View {
    @Binding var times: [Date]
    /// Duplicate times still represent distinct rows. These IDs live for the
    /// editor's lifetime and stay attached to the surviving rows on deletion.
    @State private var rowIDs: [UUID]
    @Environment(\.calendar) private var calendar

    init(times: Binding<[Date]>) {
        _times = times
        _rowIDs = State(initialValue: times.wrappedValue.map { _ in UUID() })
    }

    var body: some View {
        ForEach(rowIDs.prefix(times.count).enumerated(), id: \.element) { index, id in
            ReminderFixedTimeRow(
                time: binding(for: id, fallback: times[index]), position: index + 1,
                canRemove: times.count > 1, remove: { removeTime(id) }
            )
        }
        if times.count < ReminderSchedule.maxPerDay {
            Button(action: addTime) {
                Label("Add a time", systemImage: "plus.circle")
            }
        }
    }

    /// Resolve by identity on every access: a disappearing row must never
    /// write into the row that moved into its former array position.
    private func binding(for id: UUID, fallback: Date) -> Binding<Date> {
        Binding(
            get: {
                guard let index = rowIDs.firstIndex(of: id), times.indices.contains(index) else {
                    return fallback
                }
                return times[index]
            },
            set: { value in
                guard let index = rowIDs.firstIndex(of: id), times.indices.contains(index) else { return }
                times[index] = value
            }
        )
    }

    private func addTime() {
        guard times.count < ReminderSchedule.maxPerDay else { return }
        let next = times.last.flatMap { calendar.date(byAdding: .hour, value: 1, to: $0) }
            ?? ReminderSchedule.time(hour: 9, calendar: calendar)
        rowIDs.append(UUID())
        times.append(next)
    }

    private func removeTime(_ id: UUID) {
        guard times.count > 1, let index = rowIDs.firstIndex(of: id), times.indices.contains(index) else { return }
        rowIDs.remove(at: index)
        times.remove(at: index)
    }
}

private struct ReminderFixedTimeRow: View {
    @Binding var time: Date
    let position: Int
    let canRemove: Bool
    let remove: () -> Void

    var body: some View {
        HStack {
            DatePicker("Time \(position)", selection: $time, displayedComponents: .hourAndMinute)
            if canRemove {
                Button(role: .destructive, action: remove) {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove time \(position)")
            }
        }
    }
}

private struct ReminderRandomRangeEditor: View {
    @Binding var start: Date
    @Binding var end: Date
    @Binding var count: Int

    var body: some View {
        DatePicker("From", selection: $start, displayedComponents: .hourAndMinute)
        DatePicker("To", selection: $end, displayedComponents: .hourAndMinute)
        Stepper(
            "\(count) \(count == 1 ? "ping" : "pings") a day",
            value: $count, in: 1 ... ReminderSchedule.maxPerDay
        )
    }
}
