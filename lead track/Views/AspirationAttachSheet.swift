import SwiftData
import SwiftUI

/// The detail screen's "Add" entry point: the attach picker on its own, applied
/// to an existing aspiration's membership when the user taps Done. Membership is
/// freely editable here too, at any point in the aspiration's life.
struct AspirationAttachSheet: View {
    @Environment(\.dismiss) private var dismiss
    let aspiration: Aspiration
    @State private var selectedMetrics: Set<Metric>
    @State private var selectedProjects: Set<Project>

    init(aspiration: Aspiration) {
        self.aspiration = aspiration
        _selectedMetrics = State(initialValue: Set(aspiration.metrics))
        _selectedProjects = State(initialValue: Set(aspiration.projects))
    }

    var body: some View {
        NavigationStack {
            Form {
                AspirationAttachPicker(
                    selectedMetrics: $selectedMetrics,
                    selectedProjects: $selectedProjects
                )
            }
            .navigationTitle("Attach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: apply)
                }
            }
        }
    }

    private func apply() {
        aspiration.metrics = Array(selectedMetrics)
        aspiration.projects = Array(selectedProjects)
        dismiss()
    }
}
