import Foundation

/// Remembers that a Week-tab check-in card was sent away, so it stays gone for
/// the rest of that calendar week and returns on its own the next — the
/// "dismiss until next week" contract behind each card's close button and
/// swipe. Three cards use it, one `UserDefaults` key each: the per-aspiration
/// alignment pulse, the oversubscription "Check-In", and the "Intentions to
/// set" asks. Separate keys so hiding one leaves the others.
///
/// Only the dismissed week's start is stored, as its
/// `timeIntervalSinceReferenceDate`. Membership is tested by calendar week
/// (`Intention.week(starting:contains:)`), not `Date` equality, so a card
/// returns the instant the week rolls over with no scheduled reset — and, like
/// the intention layer beside it, a time-zone or first-weekday change can't
/// strand a stale dismissal inside "this week".
enum WeeklyCheckInDismissal {
    /// Key for the per-aspiration alignment pulse's dismissal. (Value unchanged
    /// from when it was the only card, so shipped dismissals still read.)
    static let alignmentWeekKey = "weeklyCheckInDismissedWeek"
    /// Key for the oversubscription "Check-In" card's dismissal.
    static let oversubscriptionWeekKey = "weeklyOversubscriptionDismissedWeek"
    /// Key for the "Intentions to set" asks' dismissal.
    static let intentionAskWeekKey = "weeklyIntentionAskDismissedWeek"

    /// The value to store to dismiss the check-in for the calendar week
    /// containing `date`.
    static func marker(for date: Date, calendar: Calendar = .current) -> Double {
        Intention.weekStart(containing: date, calendar: calendar).timeIntervalSinceReferenceDate
    }

    /// Whether a stored week-start value hides its card on `date`. The unset
    /// default of 0 lands in a week decades past, so it dismisses nothing — no
    /// separate "never dismissed" case to carry.
    static func isDismissed(
        storedWeekStart: Double,
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        Intention.week(
            starting: Date(timeIntervalSinceReferenceDate: storedWeekStart),
            contains: date,
            calendar: calendar
        )
    }
}
