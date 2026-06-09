import Foundation

struct DailyTotal: Identifiable {
    let date: Date
    let duration: TimeInterval
    let sessionCount: Int
    var id: Date {
        date
    }

    init(
        date: Date,
        duration: TimeInterval,
        sessionCount: Int = 0
    ) {
        self.date = date
        self.duration = duration
        self.sessionCount = sessionCount
    }
}

enum SessionStatistics {
    /// Number of sessions shown in a list before collapsing the remainder
    /// behind a "Show All" toggle.
    static let sessionListPreviewLimit = 10

    static func dailyTotals(from sessions: [Session]) -> [DailyTotal] {
        let calendar = Calendar.current
        var durations: [Date: TimeInterval] = [:]
        var counts: [Date: Int] = [:]
        for session in sessions where !session.isRunning {
            let day = calendar.startOfDay(for: session.startedAt)
            durations[day, default: 0] += session.trackingValue
            counts[day, default: 0] += 1
        }
        return durations
            .map {
                DailyTotal(
                    date: $0.key,
                    duration: $0.value,
                    sessionCount: counts[$0.key] ?? 0
                )
            }
            .sorted { $0.date < $1.date }
    }

    static func recentAverage(
        days: Int,
        from totals: [DailyTotal]
    ) -> TimeInterval {
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -(days - 1),
            to: Calendar.current.startOfDay(for: .now)
        ) else { return 0 }
        let recent = totals.filter { $0.date >= cutoff }
        let total = recent.reduce(0) { $0 + $1.duration }
        return total / Double(days)
    }

    static func overallAverage(
        from totals: [DailyTotal]
    ) -> TimeInterval {
        guard let first = totals.first else { return 0 }
        let dayCount = Calendar.current.dateComponents(
            [.day],
            from: first.date,
            to: Calendar.current.startOfDay(for: .now)
        ).day.map { max($0 + 1, 1) } ?? 1
        let total = totals.reduce(0) { $0 + $1.duration }
        return total / Double(dayCount)
    }

    static func maxDaily(from totals: [DailyTotal]) -> TimeInterval {
        totals.map(\.duration).max() ?? 0
    }

    static func todayTotal(from totals: [DailyTotal]) -> TimeInterval {
        let today = Calendar.current.startOfDay(for: .now)
        return totals.first { $0.date == today }?.duration ?? 0
    }

    static func overallTotal(from totals: [DailyTotal]) -> TimeInterval {
        totals.reduce(0) { $0 + $1.duration }
    }

    static func lastSevenDaysTotal(
        from totals: [DailyTotal]
    ) -> TimeInterval {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -6,
            to: Calendar.current.startOfDay(for: .now)
        ) else { return 0 }
        return totals
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + $1.duration }
    }

    static func currentWeekTotal(
        from totals: [DailyTotal]
    ) -> TimeInterval {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(
            of: .weekOfYear, for: .now
        ) else { return 0 }
        return totals
            .filter { $0.date >= week.start && $0.date < week.end }
            .reduce(0) { $0 + $1.duration }
    }

    static func totalSessions(from totals: [DailyTotal]) -> Int {
        totals.reduce(0) { $0 + $1.sessionCount }
    }

    static func averageSessionsPerDay(
        from totals: [DailyTotal]
    ) -> Double {
        guard let first = totals.first else { return 0 }
        let dayCount = Calendar.current.dateComponents(
            [.day],
            from: first.date,
            to: Calendar.current.startOfDay(for: .now)
        ).day.map { max($0 + 1, 1) } ?? 1
        return Double(totalSessions(from: totals)) / Double(dayCount)
    }

    static func recentAverageSessionsPerDay(
        days: Int,
        from totals: [DailyTotal]
    ) -> Double {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -(days - 1),
            to: Calendar.current.startOfDay(for: .now)
        ) else { return 0 }
        let count = totals
            .filter { $0.date >= cutoff }
            .reduce(0) { $0 + $1.sessionCount }
        return Double(count) / Double(days)
    }

    static func averageSessionLength(
        from totals: [DailyTotal]
    ) -> TimeInterval {
        let sessions = totalSessions(from: totals)
        guard sessions > 0 else { return 0 }
        return overallTotal(from: totals) / Double(sessions)
    }

    static func recentAverageSessionLength(
        days: Int,
        from totals: [DailyTotal]
    ) -> TimeInterval {
        guard let cutoff = Calendar.current.date(
            byAdding: .day, value: -(days - 1),
            to: Calendar.current.startOfDay(for: .now)
        ) else { return 0 }
        let recent = totals.filter { $0.date >= cutoff }
        let sessions = recent.reduce(0) { $0 + $1.sessionCount }
        guard sessions > 0 else { return 0 }
        let total = recent.reduce(0) { $0 + $1.duration }
        return total / Double(sessions)
    }

    static func currentStreak(
        from totals: [DailyTotal],
        excludedWeekdays: Set<Int> = []
    ) -> Int {
        guard excludedWeekdays.count < 7 else { return 0 }
        let dates = loggedDays(from: totals)
        let start = streakStart(dates: dates, excludedWeekdays: excludedWeekdays)
        return streakEndingAt(
            start, dates: dates, excludedWeekdays: excludedWeekdays
        )
    }

    static func longestStreak(
        from totals: [DailyTotal],
        excludedWeekdays: Set<Int> = []
    ) -> Int {
        let sorted = loggedDays(from: totals).sorted()
        guard !sorted.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1 ..< sorted.count {
            if consecutiveGoalDays(
                from: sorted[index - 1], to: sorted[index],
                excludedWeekdays: excludedWeekdays
            ) {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }
}

// MARK: - Streak Helpers

extension SessionStatistics {
    private static func loggedDays(
        from totals: [DailyTotal]
    ) -> Set<Date> {
        let calendar = Calendar.current
        return Set(totals.map { calendar.startOfDay(for: $0.date) })
    }

    private static func streakStart(
        dates: Set<Date>,
        excludedWeekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if holdsStreak(on: today, dates: dates, excludedWeekdays: excludedWeekdays) {
            return today
        }
        return calendar.date(byAdding: .day, value: -1, to: today) ?? today
    }

    private static func streakEndingAt(
        _ date: Date,
        dates: Set<Date>,
        excludedWeekdays: Set<Int>
    ) -> Int {
        let calendar = Calendar.current
        var day = calendar.startOfDay(for: date)
        var count = 0
        while holdsStreak(on: day, dates: dates, excludedWeekdays: excludedWeekdays) {
            if dates.contains(day) { count += 1 }
            guard let prev = calendar.date(
                byAdding: .day, value: -1, to: day
            ) else { break }
            day = prev
        }
        return count
    }

    /// A day keeps a streak alive when it was logged or is an excluded rest day.
    private static func holdsStreak(
        on day: Date,
        dates: Set<Date>,
        excludedWeekdays: Set<Int>
    ) -> Bool {
        if dates.contains(day) { return true }
        let weekday = Calendar.current.component(.weekday, from: day)
        return excludedWeekdays.contains(weekday)
    }

    /// Whether `later` is the next goal day after `earlier`, skipping rest days.
    private static func consecutiveGoalDays(
        from earlier: Date,
        to later: Date,
        excludedWeekdays: Set<Int>
    ) -> Bool {
        let calendar = Calendar.current
        var day = calendar.date(byAdding: .day, value: 1, to: earlier) ?? later
        while day < later {
            let weekday = calendar.component(.weekday, from: day)
            if !excludedWeekdays.contains(weekday) { return false }
            guard let next = calendar.date(
                byAdding: .day, value: 1, to: day
            ) else { return false }
            day = next
        }
        return day == later
    }
}

// MARK: - Trend Series

extension SessionStatistics {
    /// Daily totals collapsed into per-week sums for dates on or after `cutoff`.
    static func weeklyTotals(
        from totals: [DailyTotal],
        since cutoff: Date,
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let start = calendar.startOfDay(for: cutoff)
        let recent = totals.filter { $0.date >= start }
        let groups = Dictionary(grouping: recent) { weekStart(of: $0.date, calendar: calendar) }
        let weeks = groups.map { weekTotal(weekStart: $0.key, items: $0.value) }
        return weeks.sorted { $0.date < $1.date }
    }

    /// Per-day totals for the trailing `days` ending today, zero-filled so
    /// every day is present, ordered oldest to newest. Feeds sparklines that
    /// need a fixed-width window regardless of which days were logged.
    static func trailingDailySeries(
        days: Int,
        from totals: [DailyTotal],
        calendar: Calendar = .current
    ) -> [Double] {
        let today = calendar.startOfDay(for: .now)
        let byDay = durationsByDay(from: totals, calendar: calendar)
        return (0 ..< days).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)
            return byDay[day ?? today] ?? 0
        }
    }

    /// Trailing `window`-day moving average, one point per day from `cutoff`
    /// through today, so a smooth line can be overlaid on the daily bars.
    static func movingAverage(
        days window: Int,
        from totals: [DailyTotal],
        since cutoff: Date,
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let byDay = durationsByDay(from: totals, calendar: calendar)
        let today = calendar.startOfDay(for: .now)
        let start = calendar.startOfDay(for: cutoff)
        return dayRange(from: start, to: today, calendar: calendar).map { day in
            DailyTotal(
                date: day,
                duration: trailingAverage(ending: day, window: window, byDay: byDay, calendar: calendar)
            )
        }
    }
}

// MARK: - Trend Series Helpers

extension SessionStatistics {
    private static func weekStart(of date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
    }

    private static func weekTotal(
        weekStart: Date,
        items: [DailyTotal]
    ) -> DailyTotal {
        DailyTotal(
            date: weekStart,
            duration: items.reduce(0) { $0 + $1.duration },
            sessionCount: items.reduce(0) { $0 + $1.sessionCount }
        )
    }

    private static func durationsByDay(
        from totals: [DailyTotal],
        calendar: Calendar
    ) -> [Date: TimeInterval] {
        var result: [Date: TimeInterval] = [:]
        for total in totals {
            result[calendar.startOfDay(for: total.date), default: 0] += total.duration
        }
        return result
    }

    private static func dayRange(
        from start: Date,
        to end: Date,
        calendar: Calendar
    ) -> [Date] {
        var days: [Date] = []
        var day = start
        while day <= end {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return days
    }

    private static func trailingAverage(
        ending day: Date,
        window: Int,
        byDay: [Date: TimeInterval],
        calendar: Calendar
    ) -> TimeInterval {
        var sum = 0.0
        for offset in 0 ..< window {
            let prior = calendar.date(byAdding: .day, value: -offset, to: day)
            sum += byDay[prior ?? day] ?? 0
        }
        return sum / Double(window)
    }
}
