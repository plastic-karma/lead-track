import Foundation

/// One metric's recorded effort; unlike units are never added together. Rows
/// retain the actual sessions so history can be explored without editing it.
struct RetrospectiveEffort: Identifiable {
    let id: ObjectIdentifier
    let name: String
    let metric: Metric?
    let sessions: [Session]

    var total: Double {
        sessions.reduce(0) { $0 + $1.trackingValue }
    }

    var text: String {
        ValueFormatter.format(total, type: metric?.measurementType ?? .duration, unit: metric?.unit)
    }

    static func read(
        history: RetrospectiveHistory,
        period: DateInterval,
        filter: RetrospectiveFilter
    ) -> [RetrospectiveEffort] {
        // Sessions have no principle tag. Showing owner-wide effort here would
        // silently turn a vow into an effort attribution that was never saved.
        guard filter.principle == nil else { return [] }
        let sessions = eligibleSessions(history: history, period: period, filter: filter)
        let groups = Dictionary(grouping: sessions, by: identity)
        return groups.compactMap { key, sessions in
            guard let first = sessions.first else { return nil }
            let metric = first.metric ?? first.project?.metric
            return RetrospectiveEffort(
                id: key, name: metric?.name ?? first.project?.name ?? "Recorded effort",
                metric: metric, sessions: sessions.sorted { $0.startedAt < $1.startedAt }
            )
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func eligibleSessions(
        history: RetrospectiveHistory,
        period: DateInterval,
        filter: RetrospectiveFilter
    ) -> [Session] {
        let candidates: [Session]
        if let aspiration = filter.aspiration {
            candidates = AspirationRollup.contributionSources(of: aspiration).flatMap(\.sessions)
        } else {
            candidates = history.metrics.flatMap(\.sessions) + history.projects.flatMap(\.sessions)
        }
        var seen: Set<ObjectIdentifier> = []
        return candidates.filter {
            !$0.isRunning && RetrospectiveReader.contains($0.startedAt, in: period)
                && (filter.project == nil || $0.project === filter.project)
                && seen.insert(ObjectIdentifier($0)).inserted
        }
    }

    private static func identity(of session: Session) -> ObjectIdentifier {
        if let metric = session.metric ?? session.project?.metric {
            return ObjectIdentifier(metric)
        }
        if let project = session.project { return ObjectIdentifier(project) }
        return ObjectIdentifier(session)
    }
}
