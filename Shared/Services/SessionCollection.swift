import Foundation

/// The one rule for gathering a metric's completed effort: a session belongs
/// to a metric directly or through one of its projects, counts once even
/// when reachable both ways, never counts while running, and is windowed
/// half-open on `startedAt` — the `SessionStatistics` convention.
/// `IntentionProgress` and `MarkdownExportWindow` share this instead of
/// keeping drift-prone hand-rolled copies.
enum SessionCollection {
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
