import SwiftUI

struct WatchRootView: View {
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
                WatchMetricsContent(date: timeline.date)
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
}

private struct WatchMetricsContent: View {
    @Environment(WatchSyncController.self) private var sync
    let date: Date

    var body: some View {
        let metrics = WatchSnapshotReducer.rolledForward(sync.snapshot, to: date).metrics
        if metrics.isEmpty {
            WatchMetricsEmptyState()
        } else {
            List(metrics) { metric in
                WatchMetricRow(metric: metric)
            }
        }
    }
}

private struct WatchMetricsEmptyState: View {
    var body: some View {
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
