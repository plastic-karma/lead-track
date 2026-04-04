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
}
