import Foundation

/// Optimistically updates the watch's local snapshot when an action is sent,
/// so the UI reacts instantly while the phone confirms in the background.
enum WatchSnapshotReducer {
    static func applying(
        _ action: WatchAction,
        to snapshot: WatchSnapshot,
        calendar: Calendar = .current
    ) -> WatchSnapshot {
        var next = rolledForward(snapshot, to: action.timestamp, calendar: calendar)
        guard let index = next.metrics.firstIndex(where: { $0.id == action.metricID })
        else { return next }
        next.metrics[index] = applying(action, to: next.metrics[index])
        return next
    }

    /// Zeroes the day-scoped totals when the snapshot describes a different
    /// day than `date`, so an overnight action starts a fresh day instead of
    /// inflating yesterday's numbers. Snapshots without a day stamp (caches
    /// from older app versions) are left untouched.
    static func rolledForward(
        _ snapshot: WatchSnapshot,
        to date: Date,
        calendar: Calendar = .current
    ) -> WatchSnapshot {
        guard let day = snapshot.day, !calendar.isDate(day, inSameDayAs: date)
        else { return snapshot }
        var next = snapshot
        next.day = calendar.startOfDay(for: date)
        for index in next.metrics.indices {
            next.metrics[index].todayTotal = 0
        }
        return next
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
