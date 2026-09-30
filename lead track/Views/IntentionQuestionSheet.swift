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
                IntentionDailyQuestionSection(asksDaily: $asksDaily, question: $question)
                if let owner = intention.aspiration, owner.isArchived {
                    Section {
                        Text("Questions are paused while this aspiration is set aside.")
                        AspirationShelvingControl(aspiration: owner)
                    }
                }
            }
            .navigationTitle("Daily Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarButtons }
        }
        .presentationDetents([.medium])
    }

    @ToolbarContentBuilder
    private var toolbarButtons: some ToolbarContent {
        ToolbarItem(placement: .confirmationAction) {
            Button("Save", action: save)
                .disabled(!IntentionQuestionPlanner.isEligible(intention)
                    || (asksDaily && question.trimmedText.isEmpty))
        }
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
        }
    }

    private func save() {
        guard IntentionQuestionPlanner.isEligible(intention) else { return }
        intention.applyQuestion(asksDaily ? question : nil)
        NotificationService.rescheduleQuestion(for: intention)
        dismiss()
    }
}
