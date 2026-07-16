import Foundation

/// Remembers that the Week tab's alignment check-in was swiped away, so it
/// stays gone for the rest of that calendar week and returns on its own the
/// next — the "dismiss until next week" contract, held in the one
/// `UserDefaults` key the review's `@AppStorage` binds to.
///
/// Only the dismissed week's start is stored, as its
/// `timeIntervalSinceReferenceDate`. Membership is tested by calendar week
/// (`Intention.week(starting:contains:)`), not `Date` equality, so the section
/// returns the instant the week rolls over with no scheduled reset — and, like
/// the intention layer it sits beside, a time-zone or first-weekday change
/// can't strand a stale dismissal inside "this week".
enum WeeklyCheckInDismissal {
    /// The `@AppStorage`/`UserDefaults` key holding the dismissed week's start.
    static let dismissedWeekKey = "weeklyCheckInDismissedWeek"

    /// The value to store to dismiss the check-in for the calendar week
    /// containing `date`.
    static func marker(for date: Date, calendar: Calendar = .current) -> Double {
        Intention.weekStart(containing: date, calendar: calendar).timeIntervalSinceReferenceDate
    }

    /// Whether a stored `dismissedWeekKey` value hides the check-in on `date`.
    /// The unset default of 0 lands in a week decades past, so it dismisses
    /// nothing — no separate "never dismissed" case to carry.
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
