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

    static func currentStreak(from totals: [DailyTotal]) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dates = Set(
            totals.map { calendar.startOfDay(for: $0.date) }
        )
        let start = if dates.contains(today) {
            today
        } else if let yesterday = calendar.date(
            byAdding: .day, value: -1, to: today
        ) {
            yesterday
        } else {
            today
        }
        return streakEndingAt(start, from: totals)
    }

    static func longestStreak(from totals: [DailyTotal]) -> Int {
        let calendar = Calendar.current
        let sorted = Set(
            totals.map { calendar.startOfDay(for: $0.date) }
        ).sorted()
        guard !sorted.isEmpty else { return 0 }
        var best = 1
        var current = 1
        for index in 1 ..< sorted.count {
            let expected = calendar.date(
                byAdding: .day, value: 1,
                to: sorted[index - 1]
            )
            if sorted[index] == expected {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
        }
        return best
    }

    private static func streakEndingAt(
        _ date: Date,
        from totals: [DailyTotal]
    ) -> Int {
        let calendar = Calendar.current
        let dates = Set(
            totals.map { calendar.startOfDay(for: $0.date) }
        )
        var day = calendar.startOfDay(for: date)
        var count = 0
        while dates.contains(day) {
            count += 1
            guard let prev = calendar.date(
                byAdding: .day, value: -1, to: day
            ) else { break }
            day = prev
        }
        return count
    }
}
