import SwiftUI

struct WatchRootView: View {
    @Environment(WatchSyncController.self) private var sync
    /// Metric IDs pushed onto the stack — a Metric Progress complication tap
    /// drives this so the app opens on the metric it shows.
    @State private var path: [UUID] = []

    var body: some View {
        NavigationStack(path: $path) {
            // The complications zero totals that went stale overnight; the
            // in-app list resolves against the clock the same way, so both
            // agree when the app opens after midnight with the phone
            // unreachable (yesterday's "Done today" must not carry over).
            TimelineView(.everyMinute) { timeline in
                content(at: timeline.date)
            }
            .navigationTitle("LeadStone")
            .navigationDestination(for: UUID.self) { metricID in
                WatchMetricDetailView(metricID: metricID)
            }
        }
        .onOpenURL { open($0) }
    }

    /// Focus the metric a complication points at, ignoring any link that
    /// isn't one of ours.
    private func open(_ url: URL) {
        guard let metricID = WatchMetricDeepLink.metricID(from: url) else { return }
        path = [metricID]
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
