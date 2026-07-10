import Foundation

/// Bridges the intention's stored question fields to the `IntentionQuestion`
/// value type the editor and scheduler work with — the
/// `Metric+ReminderSchedule` pattern one layer down.
extension Intention {
    /// The daily-question configuration, or nil when no question is asked.
    var question: IntentionQuestion? {
        guard let text = questionText, !text.isEmpty,
              let start = questionWindowStart,
              let end = questionWindowEnd
        else { return nil }
        return IntentionQuestion(text: text, windowStart: start, windowEnd: end)
    }

    /// Persists an edited question, or clears it when nil or blank.
    func applyQuestion(_ question: IntentionQuestion?) {
        guard let question, !question.trimmedText.isEmpty else {
            questionText = nil
            questionWindowStart = nil
            questionWindowEnd = nil
            return
        }
        questionText = question.trimmedText
        questionWindowStart = question.windowStart
        questionWindowEnd = question.windowEnd
    }
}
