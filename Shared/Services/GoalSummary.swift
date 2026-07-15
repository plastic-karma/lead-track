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
        now: Date = .now,
        calendar: Calendar = .current
    ) -> GoalSummary {
        let active = metrics.filter {
            hasDailyTarget($0) && $0.isGoalDay(on: now, calendar: calendar)
        }
        let met = active.filter { isDailyMet($0, now: now, calendar: calendar) }
        return GoalSummary(met: met.count, total: active.count)
    }

    /// Whether the metric's daily target is met today — the same rule the
    /// daily ring counts by, so the Today screen can sort cards into "left"
    /// and "done" sections that agree with the summary. Metrics without a
    /// target today (no goal, or resting) are never "complete".
    static func isDailyComplete(
        _ metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Bool {
        guard hasDailyTarget(metric),
              metric.isGoalDay(on: now, calendar: calendar)
        else {
            return false
        }
        return isDailyMet(metric, now: now, calendar: calendar)
    }

    /// Binary metrics carry an implicit "do it today" goal until it is
    /// retired (see `Metric.expectsDailyShowUp`); the others only count
    /// toward the summary once an amount goal is set. Internal (not
    /// private): Today's cluster states and day dial share this exact
    /// definition of "has a daily target".
    static func hasDailyTarget(_ metric: Metric) -> Bool {
        DailyTargetRule.exists(
            measurementType: metric.measurementType,
            binaryGoalRetiredAt: metric.binaryGoalRetiredAt,
            dailyGoal: metric.dailyGoal
        )
    }

    private static func isDailyMet(
        _ metric: Metric,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        let today = SessionStatistics.todayTotal(
            from: metric.sessions, now: now, calendar: calendar
        )
        if metric.measurementType == .binary {
            return today > 0
        }
        return today >= (metric.dailyGoal ?? 0)
    }

    /// Weekly goal completion across metrics.
    static func weekly(
        for metrics: [Metric],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> GoalSummary {
        let active = metrics.filter { $0.weeklyGoal != nil }
        let met = active.filter {
            SessionStatistics.currentWeekTotal(from: $0.sessions, now: now, calendar: calendar)
                >= ($0.weeklyGoal ?? 0)
        }
        return GoalSummary(met: met.count, total: active.count)
    }
}
