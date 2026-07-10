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
