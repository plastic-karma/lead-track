import Foundation

struct DailyTotal: Identifiable {
    let date: Date
    let duration: TimeInterval
    var id: Date {
        date
    }
}

enum SessionStatistics {
    static func dailyTotals(from sessions: [Session]) -> [DailyTotal] {
        let calendar = Calendar.current
        var grouped: [Date: TimeInterval] = [:]
        for session in sessions where !session.isRunning {
            let day = calendar.startOfDay(for: session.startedAt)
            grouped[day, default: 0] += session.duration
        }
        return grouped
            .map { DailyTotal(date: $0.key, duration: $0.value) }
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
        let dates = Set(
            totals.map {
                Calendar.current.startOfDay(for: $0.date)
            }
        )
        guard !dates.isEmpty else { return 0 }
        var best = 0
        for date in dates {
            let streak = streakEndingAt(date, from: totals)
            best = max(best, streak)
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
