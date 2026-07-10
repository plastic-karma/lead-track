import SwiftData
import SwiftUI

/// Edits an intention's daily question after creation — reached from the row
/// context menu. Seeds local state from the model and touches it only on
/// Save, rescheduling the pending asks on the way out (the `GoalSettingsView`
/// host pattern).
struct IntentionQuestionSheet: View {
    let intention: Intention
    @Environment(\.dismiss) private var dismiss

    @State private var asksDaily: Bool
    @State private var question: IntentionQuestion

    init(intention: Intention) {
        self.intention = intention
        let existing = intention.question
        _asksDaily = State(initialValue: existing != nil)
        _question = State(initialValue: existing ?? .makeDefault())
    }

    var body: some View {
        NavigationStack {
            Form {
                questionSection
            }
            .navigationTitle("Daily Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarButtons }
        }
        .presentationDetents([.medium])
    }

    private var questionSection: some View {
        Section {
            Toggle("Daily Question", isOn: $asksDaily)
            if asksDaily {
                IntentionQuestionEditor(question: $question)
            }
        } footer: {
            if asksDaily {
                Text("Asks once a day, at a random time inside your window, through the end of the week.")
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(asksDaily && question.trimmedText.isEmpty)
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private func save() {
        intention.applyQuestion(asksDaily ? question : nil)
        NotificationService.rescheduleQuestion(for: intention)
        dismiss()
    }
}
