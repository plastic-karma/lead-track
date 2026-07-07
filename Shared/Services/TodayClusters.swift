import Foundation

// The "smart" in Today's smart-ordered clusters: every aspiration cluster is
// classified by how it relates to the day, which decides whether it renders
// as a full card or a one-line stub, and where it sits on the screen. Pure
// logic, unit-tested on Linux; the views only read the results.

// MARK: - Cluster States

extension TodayGrouping {
    /// How a cluster relates to the day. Declaration order is render order:
    /// clusters that need the user open the screen full, everything else
    /// compresses into stubs below them.
    enum ClusterState: Int, Comparable {
        /// Something can still be done today: an unmet active daily target,
        /// or a goal-less manual metric (always open to effort).
        case needsYou
        /// Nothing is expected today — every unmet member is resting on an
        /// excluded weekday (or the cluster holds only intentions).
        case resting
        /// Every metric targeted today has met its goal.
        case done
        /// Health-linked members only: the day fills itself from Apple
        /// Health, so there is nothing to start or log.
        case selfFilling

        static func < (lhs: ClusterState, rhs: ClusterState) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// One aspiration's cluster on Today — its metrics, this week's open
    /// intentions, and the state deciding full-vs-stub rendering. The
    /// trailing unaligned pseudo-cluster carries no aspiration.
    struct Cluster: Identifiable {
        let aspiration: Aspiration?
        let metrics: [Metric]
        let intentions: [Intention]
        let state: ClusterState

        var id: String {
            guard let aspiration else { return "unaligned" }
            return aspiration.stableID?.uuidString ?? aspiration.title
        }
    }
}

// MARK: - Classification

extension TodayGrouping {
    /// The state a single metric contributes to its cluster. Health-linked
    /// metrics never need the user (their sessions arrive on their own);
    /// goal-less manual metrics always do (there is always something worth
    /// logging, so their cluster never folds).
    static func metricState(
        _ metric: Metric,
        calendar: Calendar = .current
    ) -> ClusterState {
        if metric.isHealthLinked { return .selfFilling }
        guard GoalSummary.hasDailyTarget(metric) else { return .needsYou }
        guard metric.isGoalDay(on: .now, calendar: calendar) else { return .resting }
        return GoalSummary.isDailyComplete(metric, calendar: calendar) ? .done : .needsYou
    }

    /// A whole cluster's state: needy if any member is, done once everything
    /// targeted today is met, resting when only rest-day members remain, and
    /// self-filling when Apple Health does all the work. An empty member
    /// list (an intentions-only cluster) rests.
    static func clusterState(
        of metrics: [Metric],
        calendar: Calendar = .current
    ) -> ClusterState {
        let states = metrics.map { metricState($0, calendar: calendar) }
        if states.contains(.needsYou) { return .needsYou }
        if states.contains(.done) { return .done }
        if states.contains(.resting) || states.isEmpty { return .resting }
        return .selfFilling
    }

    /// How close a metric stands to today's goal, 0–1. Binary habits are met
    /// whole or not at all; metrics without an amount goal never progress.
    static func completionFraction(
        _ metric: Metric,
        calendar: Calendar = .current
    ) -> Double {
        let today = SessionStatistics.todayTotal(from: metric.sessions, calendar: calendar)
        if metric.measurementType == .binary { return today > 0 ? 1 : 0 }
        guard let goal = metric.dailyGoal, goal > 0 else { return 0 }
        return min(today / goal, 1)
    }

    /// The needsYou tie-breaker — the neediest unmet fraction in the
    /// cluster, so the cluster closest to completion leads and one small win
    /// brings the day's ring forward.
    static func urgency(
        of metrics: [Metric],
        calendar: Calendar = .current
    ) -> Double {
        metrics
            .filter { metricState($0, calendar: calendar) == .needsYou }
            .map { completionFraction($0, calendar: calendar) }
            .max() ?? 0
    }
}

// MARK: - Assembly & Ordering

extension TodayGrouping {
    /// The whole smart-ordered Today arrangement: one cluster per aspiration
    /// holding metrics or open intentions this week — needsYou first
    /// (closest to completion leading), then resting, done, and self-filling
    /// stubs — with the unaligned metrics as one trailing cluster, always
    /// last regardless of state.
    static func clusters(
        metrics: [Metric],
        aspirations: [Aspiration],
        intentions: [Intention],
        calendar: Calendar = .current
    ) -> [Cluster] {
        let split = groups(metrics: metrics, aspirations: aspirations)
        let open = intentions.filter { $0.isOpen && $0.isInCurrentWeek(calendar: calendar) }
        let aligned = alignedClusters(
            groups: split.groups, aspirations: aspirations,
            intentions: open, calendar: calendar
        )
        guard !split.unaligned.isEmpty else { return aligned }
        let trailing = Cluster(
            aspiration: nil, metrics: split.unaligned, intentions: [],
            state: clusterState(of: split.unaligned, calendar: calendar)
        )
        return aligned + [trailing]
    }

    /// An aspiration becomes a cluster when it holds metrics or open
    /// intentions. A metrics-less cluster rests — its intentions still
    /// render, since stubs never fold them.
    private static func alignedClusters(
        groups: [Group], aspirations: [Aspiration],
        intentions: [Intention], calendar: Calendar
    ) -> [Cluster] {
        let clusters = aspirations
            .sorted { $0.createdAt < $1.createdAt }
            .compactMap { aspiration -> Cluster? in
                let members = groups.first { $0.aspiration === aspiration }?.metrics ?? []
                let mine = intentions.filter { $0.aspiration === aspiration }
                guard !members.isEmpty || !mine.isEmpty else { return nil }
                return Cluster(
                    aspiration: aspiration, metrics: members, intentions: mine,
                    state: clusterState(of: members, calendar: calendar)
                )
            }
        return ordered(clusters, calendar: calendar)
    }

    /// Render order: needsYou → resting → done → selfFilling. Within
    /// needsYou the cluster closest to completion leads; every other tie
    /// keeps aspiration creation order (the sort is stable).
    private static func ordered(
        _ clusters: [Cluster],
        calendar: Calendar
    ) -> [Cluster] {
        clusters.sorted { lhs, rhs in
            guard lhs.state == rhs.state else { return lhs.state < rhs.state }
            guard lhs.state == .needsYou else { return false }
            return urgency(of: lhs.metrics, calendar: calendar)
                > urgency(of: rhs.metrics, calendar: calendar)
        }
    }
}

// MARK: - Status & Insight Readings

extension TodayGrouping {
    /// The next day a resting metric's goal applies again — the stub's
    /// "resting until Monday". nil when nothing rests, or nothing ever
    /// resumes (every weekday excluded).
    static func nextGoalDate(
        for metrics: [Metric],
        calendar: Calendar = .current
    ) -> Date? {
        let resting = metrics.filter { metricState($0, calendar: calendar) == .resting }
        guard !resting.isEmpty else { return nil }
        return (1 ... 7).lazy
            .compactMap { calendar.date(byAdding: .day, value: $0, to: .now) }
            .first { day in resting.contains { $0.isGoalDay(on: day, calendar: calendar) } }
    }

    /// The unmet metric closest to completion — the subject of the cluster's
    /// insight line.
    static func neediestMetric(
        in metrics: [Metric],
        calendar: Calendar = .current
    ) -> Metric? {
        metrics
            .filter { metricState($0, calendar: calendar) == .needsYou }
            .max {
                completionFraction($0, calendar: calendar)
                    < completionFraction($1, calendar: calendar)
            }
    }

    /// What today's goal still lacks, or nil when nothing measurable does:
    /// binary habits are kept whole or not at all, and goal-less metrics
    /// have no remainder.
    static func remainingToday(
        for metric: Metric,
        calendar: Calendar = .current
    ) -> Double? {
        guard metric.measurementType != .binary, let goal = metric.dailyGoal else { return nil }
        let today = SessionStatistics.todayTotal(from: metric.sessions, calendar: calendar)
        return today < goal ? goal - today : nil
    }

    /// The folded needsYou stub's status: the lone unmet metric's measurable
    /// remainder ("1m 18s left"), or how many members still wait ("2 still
    /// open"); a single member without a remainder drops the count.
    static func openSummary(
        for metrics: [Metric],
        calendar: Calendar = .current
    ) -> String {
        let open = metrics.filter { metricState($0, calendar: calendar) == .needsYou }
        if open.count == 1, let metric = open.first {
            guard let remaining = remainingToday(for: metric, calendar: calendar)
            else { return "still open" }
            let amount = ValueFormatter.format(
                remaining, type: metric.measurementType, unit: metric.unit
            )
            return "\(amount) left"
        }
        return "\(open.count) still open"
    }

    /// The done stub's testimony, from the day's sessions: "all done ·
    /// 3m 12s reading · scripture kept" — one fragment per met metric.
    static func doneSummary(
        for metrics: [Metric],
        calendar: Calendar = .current
    ) -> String {
        let fragments = metrics
            .filter { metricState($0, calendar: calendar) == .done }
            .map { doneFragment($0, calendar: calendar) }
        return (["all done"] + fragments).joined(separator: " · ")
    }

    private static func doneFragment(_ metric: Metric, calendar: Calendar) -> String {
        let today = SessionStatistics.todayTotal(from: metric.sessions, calendar: calendar)
        switch metric.measurementType {
        case .binary:
            return "\(metric.name.lowercased()) kept"
        case .duration:
            return "\(DurationFormatter.format(today)) \(metric.name.lowercased())"
        case .count:
            guard let unit = metric.unit, !unit.isEmpty else {
                return "\(Int(today)) \(metric.name.lowercased())"
            }
            return "\(Int(today)) \(unit)"
        }
    }
}
