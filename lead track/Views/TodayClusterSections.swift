import SwiftData
import SwiftUI

/// Today's smart-ordered cluster arrangement (see `TodayGrouping.clusters`):
/// every cluster is one collapsible card, all folded to their one-line stubs
/// by default so the screen opens calm and focused; tap a header to expand a
/// cluster inline. The neediest clusters still sort first, and once nothing
/// needs the user anymore, a closing caption sends the day off.
extension MetricListView {
    @ViewBuilder
    var clusterSections: some View {
        let clusters = TodayGrouping.clusters(
            metrics: metrics, aspirations: aspirations, intentions: intentions
        )
        ForEach(clusters) { cluster in
            ClusterStubView(
                cluster: cluster,
                runningSessions: runningSessions,
                isExpanded: expansion(of: cluster)
            )
        }
        if !clusters.isEmpty, clusters.allSatisfy({ $0.state != .needsYou }) {
            Text("Nothing left to carry. See you tomorrow.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    /// The transient expansion flag for one cluster, backed by the override
    /// map in `MetricListView`. Every cluster starts folded for a calmer,
    /// more focused screen; only the clusters the user opens are stored, so
    /// the day always reopens with everything folded again.
    private func expansion(of cluster: TodayGrouping.Cluster) -> Binding<Bool> {
        let id = cluster.id
        return Binding(
            get: { expansionOverrides[id] ?? false },
            set: { expansionOverrides[id] = $0 ? true : nil }
        )
    }
}
