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
        }
        SessionService.reconcileCountdowns(in: context)
        try context.save()
    }
}
