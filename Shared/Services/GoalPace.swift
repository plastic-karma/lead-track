import Foundation

/// Projects whether the in-progress week is on pace to reach a weekly goal.
///
/// The goal is pro-rated across the week's *goal days* — weekdays that are not
/// excluded as rest days — so a five-day-a-week target is expected to be fully
/// met by the last working day rather than smeared across the weekend. Past
/// goal days count in full and the current day counts by the share of the day
/// that has elapsed, so the expectation rises smoothly through the day.
struct GoalPace: Equatable {
    enum Status: Equatable {
        case achieved
        case ahead
        case onTrack
        case behind
    }

    let actual: TimeInterval
    let goal: TimeInterval
    let expected: TimeInterval
    let projectedTotal: TimeInterval
    let status: Status

    /// Signed gap from the pro-rated expectation; positive means ahead.
    var delta: TimeInterval {
        actual - expected
    }

    /// Whether the current pace extrapolates to reaching the goal.
    var projectedToReachGoal: Bool {
        projectedTotal >= goal
    }
}

// MARK: - Weekly Pace

extension GoalPace {
    /// Builds a pace summary for the current week, or `nil` when there is no
    /// positive goal or no goal days in the week to pace against.
    static func weekly(
        actual: TimeInterval,
        goal: TimeInterval,
        excludedWeekdays: Set<Int> = [],
        asOf: Date = .now
    ) -> GoalPace? {
        guard goal > 0 else { return nil }
        guard !goalDays(excludedWeekdays: excludedWeekdays, asOf: asOf).isEmpty else { return nil }
        let fraction = elapsedGoalFraction(excludedWeekdays: excludedWeekdays, asOf: asOf)
        let expected = goal * fraction
        return GoalPace(
            actual: actual,
            goal: goal,
            expected: expected,
            projectedTotal: projected(actual: actual, goal: goal, fraction: fraction),
            status: status(actual: actual, goal: goal, expected: expected)
        )
    }

    /// Convenience that derives the week-to-date total from daily totals.
    static func forWeek(
        dailyTotals: [DailyTotal],
        weeklyGoal: TimeInterval?,
        excludedWeekdays: [Int]
    ) -> GoalPace? {
        guard let weeklyGoal else { return nil }
        return weekly(
            actual: SessionStatistics.currentWeekTotal(from: dailyTotals),
            goal: weeklyGoal,
            excludedWeekdays: Set(excludedWeekdays)
        )
    }
}

// MARK: - Classification

private extension GoalPace {
    static let onTrackTolerance = 0.05
    static let maxProjectionMultiple = 9.0

    static func projected(
        actual: TimeInterval,
        goal: TimeInterval,
        fraction: Double
    ) -> TimeInterval {
        guard fraction > 0 else { return actual }
        let raw = actual / fraction
        return min(max(raw, actual), goal * maxProjectionMultiple)
    }

    static func status(
        actual: TimeInterval,
        goal: TimeInterval,
        expected: TimeInterval
    ) -> Status {
        if actual >= goal { return .achieved }
        let delta = actual - expected
        if abs(delta) <= goal * onTrackTolerance { return .onTrack }
        return delta > 0 ? .ahead : .behind
    }
}

// MARK: - Goal-Day Elapsed Fraction

private extension GoalPace {
    static let secondsPerDay: Double = 86400

    static func elapsedGoalFraction(
        excludedWeekdays: Set<Int>,
        asOf: Date
    ) -> Double {
        let days = goalDays(excludedWeekdays: excludedWeekdays, asOf: asOf)
        guard !days.isEmpty else { return 0 }
        let today = Calendar.current.startOfDay(for: asOf)
        let elapsed = days.reduce(0.0) { $0 + dayProgress(of: $1, today: today, asOf: asOf) }
        return min(elapsed / Double(days.count), 1.0)
    }

    static func goalDays(
        excludedWeekdays: Set<Int>,
        asOf: Date
    ) -> [Date] {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: asOf) else { return [] }
        return (0 ..< 7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: week.start) }
            .filter { $0 < week.end }
            .filter { !excludedWeekdays.contains(calendar.component(.weekday, from: $0)) }
    }

    static func dayProgress(
        of day: Date,
        today: Date,
        asOf: Date
    ) -> Double {
        if day < today { return 1.0 }
        if day > today { return 0.0 }
        return min(max(asOf.timeIntervalSince(today) / secondsPerDay, 0.0), 1.0)
    }
}
