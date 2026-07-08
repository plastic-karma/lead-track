import Foundation

// The Week tab's compact, aspiration-grouped view of the review's metrics, and
// the weekly-goal completion dial for its header — the middle timescale
// rendered in the same aspiration-first shape as Today. Pure logic,
// unit-tested on Linux; the views only read the results.

extension WeeklyReview {
    /// One aspiration's compact metric group for the Week tab: its metrics that
    /// logged effort this week, then any that stayed quiet, under the
    /// aspiration's identity. The trailing unaligned group carries no identity.
    struct MetricGroup: Identifiable {
        let id: String
        let title: String
        let icon: String?
        let colorName: String?
        let weeks: [MetricWeek]
        let quiet: [QuietMetric]
    }

    /// One arc of the header's weekly-goal dial: a metric carrying a weekly
    /// goal, its color, and how much of that goal the reviewed week met (0–1).
    struct GoalDialSegment: Identifiable {
        let id: String
        let colorName: String?
        let fraction: Double
    }

    /// Groups the reviewed metrics under the aspirations they serve — the same
    /// partition Today uses — mapping each metric back to its computed week or
    /// its quiet stub. A group appears only when at least one of its metrics
    /// logged effort this week; a wholly quiet aspiration falls to the resting
    /// line instead. Metrics serving no aspiration return as a trailing
    /// unaligned group.
    static func metricGroups(
        metrics: [Metric],
        aspirations: [Aspiration],
        weeks: [MetricWeek],
        quiet: [QuietMetric]
    ) -> [MetricGroup] {
        let weekByID = Dictionary(weeks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let quietByID = Dictionary(quiet.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let split = TodayGrouping.groups(metrics: metrics, aspirations: aspirations)

        func group(_ aspiration: Aspiration?, _ members: [Metric]) -> MetricGroup? {
            let ids = members.map { stableID(of: $0) }
            let active = ids.compactMap { weekByID[$0] }
            guard !active.isEmpty else { return nil }
            return MetricGroup(
                id: aspiration.map { stableID(of: $0) } ?? "unaligned",
                title: aspiration?.title ?? "Unaligned Effort",
                icon: aspiration?.displayIcon,
                colorName: aspiration?.colorName,
                weeks: active,
                quiet: ids.compactMap { quietByID[$0] }
            )
        }

        var groups = split.groups.compactMap { group($0.aspiration, $0.metrics) }
        if let unaligned = group(nil, split.unaligned) {
            groups.append(unaligned)
        }
        return groups
    }

    /// The header dial's arcs: one per metric with a weekly goal, each filled
    /// by the reviewed week's total against that goal. Mirrors the Today day
    /// dial, which segments the day's *daily* goals; this segments the week's.
    static func weeklyGoalSegments(
        metrics: [Metric],
        weeksBack: Int = 0,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [GoalDialSegment] {
        let bounds = PeriodBounds(weeksBack: weeksBack, now: now, calendar: calendar)
        return metrics.compactMap { metric in
            guard let goal = metric.weeklyGoal, goal > 0 else { return nil }
            let total = bounds.currentSessions(of: metric).reduce(0) { $0 + $1.trackingValue }
            return GoalDialSegment(
                id: stableID(of: metric),
                colorName: metric.colorName,
                fraction: min(total / goal, 1)
            )
        }
    }
}
