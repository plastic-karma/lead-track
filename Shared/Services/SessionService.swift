import Foundation
import SwiftData

enum SessionService {
    static func activeSession(
        for metric: Metric,
        in context: ModelContext
    ) throws -> Session? {
        let metricID = metric.persistentModelID
        let descriptor = FetchDescriptor<Session>(
            predicate: #Predicate { session in
                session.metric?.persistentModelID == metricID
                    && session.endedAt == nil
            }
        )
        return try context.fetch(descriptor).first
    }

    static func startSession(
        for metric: Metric,
        project: Project? = nil,
        in context: ModelContext
    ) throws -> Session {
        if let running = try activeSession(for: metric, in: context) {
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

    static func stopSession(
        for metric: Metric,
        in context: ModelContext
    ) throws {
        guard let running = try activeSession(
            for: metric,
            in: context
        ) else { return }
        running.endedAt = .now
    }
}
