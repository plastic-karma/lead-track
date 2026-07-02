import Foundation

/// Plans which of a timer metric's sessions still need to be written to
/// Apple Health, and as what interval. Pure planning — the export service
/// maps intervals to HealthKit samples and stamps sessions as sent. Each
/// completed session becomes one Health record covering the same span, sent
/// at most once; edits after export stay local by design.
enum HealthSessionExport {
    /// The sessions to write next, oldest first: completed, not yet sent,
    /// started since export was switched on, and long enough to represent.
    /// Nil `enabledAt` means export is off, so nothing is pending.
    static func pending(in sessions: [Session], enabledAt: Date?) -> [Session] {
        guard let enabledAt else { return [] }
        return sessions
            .filter {
                $0.healthExportedAt == nil
                    && $0.startedAt >= enabledAt
                    && interval(of: $0) != nil
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    /// The span the session occupies in Health, or nil when there is nothing
    /// to write: still running, or no positive length. Sessions holding an
    /// explicit value (e.g. imported ones) span that many seconds from their
    /// start, matching how every total in the app reads them.
    static func interval(of session: Session) -> DateInterval? {
        guard !session.isRunning else { return nil }
        let length = session.trackingValue
        guard length > 0 else { return nil }
        return DateInterval(start: session.startedAt, duration: length)
    }
}
