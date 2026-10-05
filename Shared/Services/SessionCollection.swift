import Foundation

/// Shared session selection for recorded effort and live timers. Ownership
/// can be direct or through a project; inverse arrays are not ownership.
enum SessionCollection {
    /// Without a metric, selects the first owned timer for the Live Activity.
    /// Unassigned sessions remain stored but cannot represent a metric control.
    static func runningSession(
        for metric: Metric? = nil,
        in sessions: [Session]
    ) -> Session? {
        sessions.first { session in
            guard session.isRunning,
                  let owner = session.metric ?? session.project?.metric
            else { return false }
            guard let metric else { return true }
            if owner === metric { return true }
            guard let id = metric.stableID else { return false }
            return owner.stableID == id
        }
    }

    /// Counts completed effort once, windowed half-open on `startedAt`.
    static func completedSessions(
        of metrics: [Metric],
        startingIn window: DateInterval? = nil
    ) -> [Session] {
        var seen = Set<ObjectIdentifier>()
        return metrics
            .flatMap { $0.sessions + $0.projects.flatMap(\.sessions) }
            .filter { session in
                !session.isRunning
                    && qualifies(session.startedAt, window: window)
                    && seen.insert(ObjectIdentifier(session)).inserted
            }
    }

    private static func qualifies(_ date: Date, window: DateInterval?) -> Bool {
        guard let window else { return true }
        return date >= window.start && date < window.end
    }
}
