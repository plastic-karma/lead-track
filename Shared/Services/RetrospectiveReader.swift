import Foundation

/// Explicit history includes set-aside aspirations and archived metrics. These
/// relationships describe today's attachments, not a reconstructed past graph.
struct RetrospectiveHistory {
    var aspirations: [Aspiration]
    var metrics: [Metric]
    var projects: [Project] = []
}

struct RetrospectiveFilter {
    var aspiration: Aspiration?
    var principle: Principle?
    var project: Project?

    func includes(_ moment: Moment) -> Bool {
        (principle == nil || moment.principle === principle)
            && (project == nil || moment.project === project)
    }
}

struct RetrospectiveSnapshot {
    let moments: [Moment]
    let intentions: [Intention]
    let checkIns: [AspirationCheckIn]
    let effort: [RetrospectiveEffort]

    var isEmpty: Bool {
        moments.isEmpty && intentions.isEmpty && checkIns.isEmpty && effort.isEmpty
    }
}

enum RetrospectiveReader {
    static func read(
        history: RetrospectiveHistory,
        period: DateInterval,
        filter: RetrospectiveFilter = RetrospectiveFilter()
    ) -> RetrospectiveSnapshot {
        let aspirations = history.aspirations.filter {
            filter.aspiration == nil || $0 === filter.aspiration
        }
        return RetrospectiveSnapshot(
            moments: aspirations.flatMap(\.moments).filter {
                contains($0.occurredAt, in: period) && filter.includes($0)
            }.sorted { $0.occurredAt < $1.occurredAt },
            intentions: intentions(in: aspirations, period: period, filter: filter),
            checkIns: checkIns(in: aspirations, period: period, filter: filter),
            effort: RetrospectiveEffort.read(history: history, period: period, filter: filter)
        )
    }

    /// DateInterval.contains includes the end; persisted event windows do not.
    static func contains(_ date: Date, in period: DateInterval) -> Bool {
        date >= period.start && date < period.end
    }

    private static func intentions(
        in aspirations: [Aspiration],
        period: DateInterval,
        filter: RetrospectiveFilter
    ) -> [Intention] {
        guard filter.project == nil else { return [] }
        return aspirations.flatMap(\.intentions).filter {
            includes($0, in: period)
                && (filter.principle == nil || $0.principle === filter.principle)
        }.sorted { $0.weekStart < $1.weekStart }
    }

    private static func checkIns(
        in aspirations: [Aspiration],
        period: DateInterval,
        filter: RetrospectiveFilter
    ) -> [AspirationCheckIn] {
        guard filter.principle == nil, filter.project == nil else { return [] }
        return aspirations.flatMap(\.checkIns).filter {
            includes($0, in: period)
        }.sorted { $0.weekStart < $1.weekStart }
    }
}

extension RetrospectiveReader {
    /// Existence-only rediscovery relevance, without constructing or sorting a
    /// retrospective on every render. Duplicate attachments do not affect it.
    static func hasHistory(for aspiration: Aspiration, period: DateInterval) -> Bool {
        if hasNarrative(for: aspiration, period: period) { return true }
        return aspiration.metrics.contains { hasEffort($0.sessions, period: period) }
            || aspiration.projects.contains { hasEffort($0.sessions, period: period) }
    }

    private static func hasNarrative(for aspiration: Aspiration, period: DateInterval) -> Bool {
        aspiration.moments.contains { contains($0.occurredAt, in: period) }
            || aspiration.intentions.contains { includes($0, in: period) }
            || aspiration.checkIns.contains { includes($0, in: period) }
    }

    private static func hasEffort(_ sessions: [Session], period: DateInterval) -> Bool {
        sessions.contains { !$0.isRunning && contains($0.startedAt, in: period) }
    }

    private static func includes(_ intention: Intention, in period: DateInterval) -> Bool {
        contains(intention.weekStart, in: period)
            || intention.closedAt.map { contains($0, in: period) } == true
    }

    private static func includes(_ checkIn: AspirationCheckIn, in period: DateInterval) -> Bool {
        contains(checkIn.weekStart, in: period)
            && !checkIn.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
