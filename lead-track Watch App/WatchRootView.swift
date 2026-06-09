import SwiftUI

struct WatchRootView: View {
    @Environment(WatchSyncController.self) private var sync

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("LeadStone")
        }
    }

    @ViewBuilder
    private var content: some View {
        if sync.snapshot.metrics.isEmpty {
            emptyState
        } else {
            metricList
        }
    }

    private var metricList: some View {
        List(sync.snapshot.metrics) { metric in
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
