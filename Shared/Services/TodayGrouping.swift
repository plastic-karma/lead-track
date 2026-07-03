import Foundation

/// The optional aspiration-first arrangement of Today: metric cards clustered
/// under the aspiration they serve, so the first thing read on the day screen
/// is a reason, not a number. Pure partition logic, unit-tested on Linux; the
/// default (ungrouped) dashboard never calls it.
enum TodayGrouping {
    /// One aspiration's cluster of today-cards.
    struct Group: Identifiable {
        let aspiration: Aspiration
        let metrics: [Metric]

        var id: String {
            aspiration.stableID?.uuidString ?? aspiration.title
        }
    }

    /// Partitions `metrics` under the aspirations they serve. A metric
    /// belongs to an aspiration when the metric itself *or any of its
    /// projects* is attached (matching rollup semantics); with several
    /// candidates the earliest-created aspiration wins, so no card is ever
    /// duplicated — a duplicate would double live timer affordances and break
    /// the day's arithmetic. Groups follow aspiration creation order (the
    /// app's canonical aspiration order), metrics keep their incoming order,
    /// and metrics serving no aspiration return in `unaligned`.
    static func groups(
        metrics: [Metric],
        aspirations: [Aspiration]
    ) -> (groups: [Group], unaligned: [Metric]) {
        let ordered = aspirations.sorted { $0.createdAt < $1.createdAt }
        var members: [[Metric]] = Array(repeating: [], count: ordered.count)
        var unaligned: [Metric] = []
        for metric in metrics {
            if let index = ordered.firstIndex(where: { serves($0, metric: metric) }) {
                members[index].append(metric)
            } else {
                unaligned.append(metric)
            }
        }
        let groups = zip(ordered, members)
            .filter { !$0.1.isEmpty }
            .map { Group(aspiration: $0.0, metrics: $0.1) }
        return (groups, unaligned)
    }

    /// Whether the metric or any of its projects is attached to the
    /// aspiration.
    static func serves(_ aspiration: Aspiration, metric: Metric) -> Bool {
        if aspiration.metrics.contains(where: { $0 === metric }) { return true }
        return aspiration.projects.contains { $0.metric === metric }
    }
}
