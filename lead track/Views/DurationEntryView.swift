import SwiftUI

struct DurationEntryView: View {
    let metric: Metric
    let project: Project?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 30
    @State private var startedAt = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    Stepper(
                        "\(hours) h",
                        value: $hours, in: 0 ... 23
                    )
                    Stepper(
                        "\(minutes) min",
                        value: $minutes, in: 0 ... 59
                    )
                }
                Section("Started At") {
                    DatePicker(
                        "Start",
                        selection: $startedAt,
                        in: ...Date.now
                    )
                    .labelsHidden()
                }
            }
            .navigationTitle("Log \(metric.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(duration == 0)
                }
            }
        }
    }

    private var duration: TimeInterval {
        TimeInterval(hours * 3600 + minutes * 60)
    }

    private func save() {
        guard duration > 0 else { return }
        SessionService.logDuration(
            duration,
            startedAt: startedAt,
            for: metric,
            project: project,
            in: modelContext
        )
        dismiss()
    }
}
