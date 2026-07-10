import SwiftUI

struct WatchRootView: View {
    @Environment(WatchSyncController.self) private var sync

    var body: some View {
        NavigationStack {
            // The complications zero totals that went stale overnight; the
            // in-app list resolves against the clock the same way, so both
            // agree when the app opens after midnight with the phone
            // unreachable (yesterday's "Done today" must not carry over).
            TimelineView(.everyMinute) { timeline in
                content(at: timeline.date)
            }
            .navigationTitle("LeadStone")
        }
    }

    @ViewBuilder
    private func content(at date: Date) -> some View {
        let snapshot = WatchSnapshotReducer.rolledForward(sync.snapshot, to: date)
        if snapshot.metrics.isEmpty {
            emptyState
        } else {
            metricList(snapshot.metrics)
        }
    }

    private func metricList(_ metrics: [WatchMetricSnapshot]) -> some View {
        List(metrics) { metric in
            WatchMetricRow(metric: metric)
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No Metrics Yet")
                    .font(.headline)
                Text("Open LeadStone on your iPhone to sync your metrics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
