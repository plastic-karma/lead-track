import Foundation

/// How a metric's daily reminder is timed. Either a handful of fixed times of
/// day, or a number of pings dropped at random moments inside a daily window
/// ("ping me twice any time between 8am and 8pm"). A plain value type shared by
/// the goal-settings editor, the notification scheduler, and their tests, so it
/// carries no UserNotifications or SwiftUI dependency and builds on Linux.
struct ReminderSchedule: Equatable {
    enum Mode: String {
        case fixed
        case random
    }

    /// The most times a reminder can fire in one day, in either mode.
    static let maxPerDay = 3

    var mode: Mode
    /// Fixed mode: the times of day to fire (1...`maxPerDay`). Carried along in
    /// random mode too, so switching modes in the editor is lossless.
    var fixedTimes: [Date]
    /// Random mode: the daily window the pings land in.
    var rangeStart: Date
    var rangeEnd: Date
    /// Random mode: how many pings to drop in the window (1...`maxPerDay`).
    var count: Int
}

// MARK: - Defaults & Normalization

extension ReminderSchedule {
    /// A sensible starting point when the reminder is first switched on: a
    /// single fixed 9am ping, with the random window pre-filled 8am–8pm twice
    /// so flipping to random mode is immediately usable.
    static func makeDefault(calendar: Calendar = .current) -> ReminderSchedule {
        ReminderSchedule(
            mode: .fixed,
            fixedTimes: [time(hour: 9, calendar: calendar)],
            rangeStart: time(hour: 8, calendar: calendar),
            rangeEnd: time(hour: 20, calendar: calendar),
            count: 2
        )
    }

    /// A date carrying just an hour and minute, for the time-of-day pickers.
    static func time(hour: Int, minute: Int = 0, calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }

    /// Fixed times trimmed to the allowed count.
    var normalizedFixedTimes: [Date] {
        Array(fixedTimes.prefix(Self.maxPerDay))
    }

    /// Random count held to the 1...`maxPerDay` range.
    var clampedCount: Int {
        min(max(count, 1), Self.maxPerDay)
    }
}
