import Foundation

/// Optimistically updates the watch's local snapshot when an action is sent,
/// so the UI reacts instantly while the phone confirms in the background.
enum WatchSnapshotReducer {
    static func applying(
        _ action: WatchAction,
        to snapshot: WatchSnapshot
    ) -> WatchSnapshot {
        var metrics = snapshot.metrics
        guard let index = metrics.firstIndex(where: { $0.id == action.metricID })
        else { return snapshot }
        metrics[index] = applying(action, to: metrics[index])
        return WatchSnapshot(metrics: metrics)
    }

    private static func applying(
        _ action: WatchAction,
        to metric: WatchMetricSnapshot
    ) -> WatchMetricSnapshot {
        // Health-linked metrics mirror Apple Health; no tap may change them.
        guard !metric.isHealthLinked else { return metric }
        var metric = metric
        switch action.kind {
        case .startTimer:
            metric.runningSince = metric.runningSince ?? action.timestamp
        case .stopTimer:
            if let since = metric.runningSince {
                metric.todayTotal += max(action.timestamp.timeIntervalSince(since), 0)
            }
            metric.runningSince = nil
        case .logValue:
            metric.todayTotal += action.value ?? 1
        case .toggleDay:
            metric.todayTotal = metric.todayTotal > 0 ? 0 : 1
        }
        return metric
    }
}
