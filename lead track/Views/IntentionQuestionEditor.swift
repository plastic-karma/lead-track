import SwiftUI

/// The daily-question rows shared by the intention form and the
/// post-creation sheet: the question in the user's words, and the daily
/// window the ask lands in. Renders sibling `Form` rows — the host supplies
/// the section — mirroring `ReminderScheduleEditor`'s shape.
struct IntentionQuestionEditor: View {
    @Binding var question: IntentionQuestion

    var body: some View {
        TextField("What should it ask you?", text: $question.text, axis: .vertical)
        DatePicker("From", selection: $question.windowStart, displayedComponents: .hourAndMinute)
        DatePicker("To", selection: $question.windowEnd, displayedComponents: .hourAndMinute)
    }
}

/// Shared section chrome for the creation form and the saved-question editor.
struct IntentionDailyQuestionSection: View {
    @Binding var asksDaily: Bool
    @Binding var question: IntentionQuestion

    var body: some View {
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
}
