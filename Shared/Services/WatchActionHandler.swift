import Foundation
import SwiftData

/// Applies recording actions received from the watch to the SwiftData store.
/// Sessions are backdated to the action's timestamp so commands queued while
/// the phone was unreachable still record when the user actually tapped.
enum WatchActionHandler {
    static func apply(
        _ action: WatchAction,
        in context: ModelContext
    ) throws {
        guard let metric = try metric(for: action.metricID, in: context)
        else { return }
        switch action.kind {
        case .startTimer:
            start(metric, at: action.timestamp, in: context)
        case .stopTimer:
            stop(metric, at: action.timestamp)
        case .logValue:
            log(action.value ?? 1, for: metric, at: action.timestamp, in: context)
        }
        try context.save()
    }

    private static func metric(
        for id: UUID,
        in context: ModelContext
    ) throws -> Metric? {
        let descriptor = FetchDescriptor<Metric>(
            predicate: #Predicate { $0.stableID == id }
        )
        return try context.fetch(descriptor).first
    }

    private static func start(
        _ metric: Metric,
        at timestamp: Date,
        in context: ModelContext
    ) {
        guard SessionService.activeSession(for: metric) == nil else { return }
        let session = SessionService.startSession(for: metric, in: context)
        session.startedAt = min(timestamp, .now)
    }

    private static func stop(_ metric: Metric, at timestamp: Date) {
        guard let session = SessionService.activeSession(for: metric)
        else { return }
        SessionService.stopSession(session)
        session.endedAt = max(min(timestamp, .now), session.startedAt)
    }

    private static func log(
        _ value: Double,
        for metric: Metric,
        at timestamp: Date,
        in context: ModelContext
    ) {
        let session = SessionService.logCount(value, for: metric, in: context)
        let logged = min(timestamp, .now)
        session.startedAt = logged
        session.endedAt = logged
    }
}
