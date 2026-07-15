import Foundation

/// Turns an intention's daily question into the concrete moments it should be
/// asked for the rest of the intention's week — one seeded-random minute
/// inside the window per remaining day. Pure Foundation, so it builds and
/// unit-tests on Linux; `NotificationService` wraps the returned dates in
/// one-shot triggers re-armed on every foreground pass.
enum IntentionQuestionPlanner {
    /// A question fires at most once per day of a calendar week. The day loop
    /// below and `NotificationService.cancelQuestion`'s slot sweep both count
    /// from here, so scheduled IDs can never outrun the cancel.
    static let maxSlotsPerWeek = 7

    /// One fire date per remaining day of `week`, ascending — today included
    /// only while its drawn minute is still ahead of `now`, and nothing at or
    /// past the week's end (half-open, the tick idiom). Inverted window
    /// bounds are normalized by swapping; equal bounds pin the single minute.
    static func fireDates(
        for question: IntentionQuestion,
        week: DateInterval,
        seed: UInt64,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        remainingDays(of: week, from: now, calendar: calendar)
            .compactMap { fireDate(for: question, on: $0, seed: seed, calendar: calendar) }
            .filter { $0 > now && $0 < week.end }
    }

    /// The drawn moment on one day: a deterministic random minute in the
    /// window (`ReminderPlanner`'s per-day mix, count 1), so a day's ask
    /// stays put across reschedules.
    static func fireDate(
        for question: IntentionQuestion,
        on day: Date,
        seed: UInt64,
        calendar: Calendar
    ) -> Date? {
        let start = ReminderPlanner.minuteOfDay(question.windowStart, calendar: calendar)
        let end = ReminderPlanner.minuteOfDay(question.windowEnd, calendar: calendar)
        let dailySeed = ReminderPlanner.mix(seed, ReminderPlanner.dayOrdinal(day, calendar: calendar))
        return ReminderPlanner
            .randomMinutes(in: min(start, end) ... max(start, end), count: 1, seed: dailySeed)
            .first
            .flatMap { calendar.date(bySettingHour: $0 / 60, minute: $0 % 60, second: 0, of: day) }
    }

    /// Start-of-day dates from `now`'s day through the week's last day.
    private static func remainingDays(
        of week: DateInterval,
        from now: Date,
        calendar: Calendar
    ) -> [Date] {
        let first = max(calendar.startOfDay(for: now), week.start)
        return (0 ..< maxSlotsPerWeek)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: first) }
            .filter { $0 < week.end }
    }
}
