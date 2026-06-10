import Foundation
import SwiftData

/// Builds the snapshot pushed to the watch from the SwiftData store.
enum WatchSnapshotBuilder {
    static func snapshot(in context: ModelContext) -> WatchSnapshot {
        let metrics = (try? context.fetch(FetchDescriptor<Metric>())) ?? []
        return snapshot(from: metrics)
    }

    static func snapshot(from metrics: [Metric]) -> WatchSnapshot {
        let sorted = metrics.sorted { $0.createdAt < $1.createdAt }
        return WatchSnapshot(metrics: sorted.compactMap(metricSnapshot))
    }

    private static func metricSnapshot(
        for metric: Metric
    ) -> WatchMetricSnapshot? {
        guard let id = metric.stableID else { return nil }
        let completed = metric.sessions.filter { !$0.isRunning }
        let totals = SessionStatistics.dailyTotals(from: completed)
        return WatchMetricSnapshot(
            id: id,
            name: metric.name,
            measurementType: metric.measurementType,
            unit: metric.unit,
            icon: metric.icon,
            colorName: metric.colorName,
            runningSince: SessionService.activeSession(for: metric)?.startedAt,
            todayTotal: SessionStatistics.todayTotal(from: totals)
        )
    }
}
