import Foundation
import SwiftData

enum SessionService {
    static func activeSession(for metric: Metric) -> Session? {
        metric.sessions.first { $0.isRunning }
    }

    @discardableResult
    static func startSession(
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext
    ) -> Session {
        if let running = activeSession(for: metric) {
            return running
        }
        let session = Session(
            metric: metric,
            project: project,
            startedAt: .now
        )
        context.insert(session)
        return session
    }

    static func stopSession(_ session: Session) {
        session.endedAt = .now
    }

    static func stopSession(for metric: Metric) {
        guard let running = activeSession(for: metric) else { return }
        running.endedAt = .now
    }
}
