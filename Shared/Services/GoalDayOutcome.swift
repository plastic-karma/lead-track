import Foundation

/// Per-day goal judgment shared by the weekly review's goal reads
/// (`OversubscriptionInsight`, `GoalShortfall`): when a metric's days begin
/// to count, what a day totaled, and whether it met the daily target. One
/// implementation, the `GoalDayRule`/`DailyTargetRule` doctrine, so the
/// review's reads can never drift on what a miss is. Pure Foundation math,
/// exercised on Linux through its callers' suites.
enum GoalDayOutcome {
    /// The first day a metric's goal can be judged: its creation day, pulled
    /// back to its earliest logged session when history predates the row
    /// (imports). Days before a goal existed must never read as misses — a
    /// goal added today cannot rewrite earlier weeks into failures.
    static func firstLiveDay(of metric: Metric, calendar: Calendar) -> Date {
        let firstSession = metric.sessions
            .filter { !$0.isRunning }
            .map(\.startedAt)
            .min()
        return calendar.startOfDay(for: min(metric.createdAt, firstSession ?? metric.createdAt))
    }

    /// The day's completed total, in the metric's native tracking value.
    static func dayTotal(
        of metric: Metric,
        on day: Date,
        calendar: Calendar
    ) -> Double {
        metric.sessions
            .filter { !$0.isRunning && calendar.isDate($0.startedAt, inSameDayAs: day) }
            .reduce(0) { $0 + $1.trackingValue }
    }

    /// Whether a day's total met the metric's daily target — showing up for
    /// a binary habit, reaching the goal amount otherwise (the `GoalSummary`
    /// rule).
    static func isMet(_ metric: Metric, dayTotal: Double) -> Bool {
        if metric.measurementType == .binary { return dayTotal > 0 }
        return dayTotal >= (metric.dailyGoal ?? 0)
    }

    /// `isMet` over the day's computed total, for reads that don't otherwise
    /// need the amount.
    static func isMet(
        _ metric: Metric,
        on day: Date,
        calendar: Calendar
    ) -> Bool {
        isMet(metric, dayTotal: dayTotal(of: metric, on: day, calendar: calendar))
    }
}
