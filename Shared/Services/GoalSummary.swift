import Foundation

/// Aggregate progress toward daily or weekly goals across every metric, so the
/// top-level list can show how many goals are done at a glance.
struct GoalSummary {
    /// Metrics whose goal for the period is already met.
    let met: Int
    /// Metrics with an active goal for the period (rest days excluded).
    let total: Int

    /// Whether there is at least one goal to track for the period.
    var hasGoals: Bool {
        total > 0
    }

    /// Whether every tracked goal for the period is met.
    var isComplete: Bool {
        total > 0 && met >= total
    }
}

// MARK: - Aggregation

extension GoalSummary {
    /// Daily goal completion across metrics. Metrics resting today (an excluded
    /// weekday) are left out entirely, so an off day never counts against you.
    static func daily(
        for metrics: [Metric],
        calendar: Calendar = .current
    ) -> GoalSummary {
        let active = metrics.filter {
            $0.dailyGoal != nil && $0.isGoalDay(on: .now, calendar: calendar)
        }
        let met = active.filter { todayTotal(for: $0) >= ($0.dailyGoal ?? 0) }
        return GoalSummary(met: met.count, total: active.count)
    }

    /// Weekly goal completion across metrics.
    static func weekly(for metrics: [Metric]) -> GoalSummary {
        let active = metrics.filter { $0.weeklyGoal != nil }
        let met = active.filter { weekTotal(for: $0) >= ($0.weeklyGoal ?? 0) }
        return GoalSummary(met: met.count, total: active.count)
    }
}

// MARK: - Per-Metric Totals

private extension GoalSummary {
    static func todayTotal(for metric: Metric) -> TimeInterval {
        SessionStatistics.todayTotal(
            from: SessionStatistics.dailyTotals(from: metric.sessions)
        )
    }

    static func weekTotal(for metric: Metric) -> TimeInterval {
        SessionStatistics.currentWeekTotal(
            from: SessionStatistics.dailyTotals(from: metric.sessions)
        )
    }
}
