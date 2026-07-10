import Foundation

/// A daily question an intention asks while it is active — the user's own
/// words, landing once per day at a seeded-random moment inside a daily
/// window ("ask me between 8am and 8pm"). A plain value type shared by the
/// intention form, the notification scheduler, and their tests, so it carries
/// no UserNotifications or SwiftUI dependency and builds on Linux.
struct IntentionQuestion: Equatable {
    /// The question, in the user's words.
    var text: String
    /// The daily window the ask lands in.
    var windowStart: Date
    var windowEnd: Date
}

// MARK: - Defaults & Normalization

extension IntentionQuestion {
    /// A sensible starting point when the question is first switched on: no
    /// text yet, with the window pre-filled 8am–8pm.
    static func makeDefault(calendar: Calendar = .current) -> IntentionQuestion {
        IntentionQuestion(
            text: "",
            windowStart: ReminderSchedule.time(hour: 8, calendar: calendar),
            windowEnd: ReminderSchedule.time(hour: 20, calendar: calendar)
        )
    }

    /// The question stripped of surrounding whitespace — the on/off
    /// criterion: a blank question is no question.
    var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
