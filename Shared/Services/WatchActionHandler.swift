import Foundation
import SwiftData

/// Applies recording actions received from the watch to the SwiftData store.
/// Each action is recorded at its own timestamp, so commands queued while the
/// phone was unreachable still land when the user actually tapped.
enum WatchActionHandler {
    static func apply(
        _ action: WatchAction,
        in context: ModelContext
    ) throws {
        guard let metric = try Metric.find(stableID: action.metricID, in: context)
        else { return }
        // A watch running an older app version may still offer recording
        // buttons on a health-linked metric; its sessions belong to the
        // HealthKit mirror, so such actions are dropped.
        guard !metric.isHealthLinked else { return }
        // A watch holding a pre-archive snapshot may likewise still offer a
        // just-archived metric. New effort on it is dropped — it would be
        // invisible on every surface — but a stop still lands, so a timer
        // racing the archive can always be ended.
        guard !metric.isArchived || action.kind == .stopTimer else { return }
        switch action.kind {
        case .startTimer:
            SessionService.startSession(for: metric, in: context, at: action.timestamp)
        case .stopTimer:
            SessionService.stopSession(for: metric, at: action.timestamp)
        case .logValue:
            SessionService.logCount(
                action.value ?? 1,
                for: metric,
                in: context,
                at: action.timestamp
            )
        case .toggleDay:
            SessionService.toggleBinaryDay(
                for: metric, in: context, at: action.timestamp
            )
        }
        SessionService.reconcileCountdowns(in: context)
        try context.save()
    }
}
