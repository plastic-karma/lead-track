import SwiftData
import SwiftUI

/// Today's smart-ordered cluster arrangement (see `TodayGrouping.clusters`):
/// every cluster is one collapsible card. Clusters that need the user start
/// expanded, neediest first; resting, done, and self-filling clusters start
/// folded into stubs. Once nothing needs the user anymore, a closing caption
/// sends the day off.
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
    /// map in `MetricListView`. The default follows the state — expanded
    /// while the cluster needs the user, folded once it doesn't — and only
    /// deviations are stored, so a cluster still folds on its own the moment
    /// its last goal completes.
    private func expansion(of cluster: TodayGrouping.Cluster) -> Binding<Bool> {
        let id = cluster.id
        let opensByDefault = cluster.state == .needsYou
        return Binding(
            get: { expansionOverrides[id] ?? opensByDefault },
            set: { expansionOverrides[id] = $0 == opensByDefault ? nil : $0 }
        )
    }
}
