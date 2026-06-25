import SwiftData
import SwiftUI

/// The menu rows for starting a countdown — quick presets plus a custom option
/// — so the dashboard card and the metric hero offer the same choices behind
/// their start control. Counting up is the control's primary tap; these are
/// the count-down alternatives.
struct CountdownOptionsMenu: View {
    let onPreset: (TimeInterval) -> Void
    let onCustom: () -> Void

    private static let presetMinutes = [5, 10, 15, 20, 25, 30, 45, 60]

    var body: some View {
        Section("Count down from") {
            ForEach(Self.presetMinutes, id: \.self) { minutes in
                Button("\(minutes) min") {
                    onPreset(TimeInterval(minutes) * 60)
                }
            }
            Button("Custom…", action: onCustom)
        }
    }
}

/// Picks an arbitrary countdown length, then starts the metric's timer
/// counting down from it. The recorded session length is still real elapsed
/// time — the countdown is display-only.
struct CountdownStartView: View {
    let metric: Metric
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 25

    var body: some View {
        NavigationStack {
            Form {
                Section("Countdown length") {
                    Stepper("\(hours) h", value: $hours, in: 0 ... 23)
                    Stepper("\(minutes) min", value: $minutes, in: 0 ... 59)
                }
            }
            .navigationTitle("Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: start)
                        .disabled(duration == 0)
                }
            }
        }
    }

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    private func start() {
        guard duration > 0 else { return }
        SessionService.startSession(
            for: metric,
            in: modelContext,
            countdownDuration: duration
        )
        dismiss()
    }
}
