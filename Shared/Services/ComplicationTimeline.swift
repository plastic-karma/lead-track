import Foundation

/// Plans the instants a snapshot-backed complication re-renders at, kept
/// pure so the schedule tests without WidgetKit. Providers map these dates
/// to entries and reload `.atEnd`: the final date is either next midnight
/// (the day resets on-face without waking the extension) or the cap of a
/// live window (so `.atEnd` extends it while a timer runs).
enum ComplicationTimeline {
    /// Spacing of live entries while a timer runs, so goal percentages stay
    /// fresh between snapshot pushes.
    static let liveSpacing: TimeInterval = 600

    /// Most live steps per timeline (two hours). Start/stop actions reload
    /// timelines anyway, so the cap only bounds how far ahead entries are
    /// pre-rendered.
    static let liveSteps = 12

    static func entryDates(
        from now: Date,
        hasRunningTimer: Bool,
        calendar: Calendar = .current
    ) -> [Date] {
        let midnight = startOfNextDay(after: now, calendar: calendar)
        guard hasRunningTimer else { return [now, midnight] }
        var dates = [now]
        for step in 1 ... liveSteps {
            let date = now.addingTimeInterval(Double(step) * liveSpacing)
            guard date < midnight else {
                dates.append(midnight)
                return dates
            }
            dates.append(date)
        }
        return dates
    }

    private static func startOfNextDay(
        after date: Date,
        calendar: Calendar
    ) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86400)
    }
}
