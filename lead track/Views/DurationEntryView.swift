import SwiftUI

struct DurationEntryView: View {
    let metric: Metric
    let project: Project?
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var hours = 0
    @State private var minutes = 30
    @State private var startedAt: Date
    @State private var saveTrigger = false

    /// `day` seeds the start picker: nil starts at now (backfilling a
    /// session that just happened), while the Today rows pass a browsed
    /// earlier day's instant so the session lands inside that day. The
    /// picker stays free to move — the seed only sets where it opens.
    init(metric: Metric, project: Project?, day: Date? = nil) {
        self.metric = metric
        self.project = project
        _startedAt = State(initialValue: day ?? .now)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    HourMinuteDurationPicker(hours: $hours, minutes: $minutes)
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
            .sensoryFeedback(.success, trigger: saveTrigger)
        }
    }

    private var duration: TimeInterval {
        HourMinuteDurationPicker.duration(hours: hours, minutes: minutes)
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
        saveTrigger.toggle()
        dismiss()
    }
}
