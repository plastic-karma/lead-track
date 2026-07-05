import SwiftData
import SwiftUI

/// Today's smart-ordered cluster arrangement (see `TodayGrouping.clusters`):
/// clusters that need the user render as full cards, neediest first;
/// resting, done, and self-filling clusters compress into stubs. Once
/// nothing needs the user anymore, a closing caption sends the day off.
extension MetricListView {
    @ViewBuilder
    var clusterSections: some View {
        let clusters = TodayGrouping.clusters(
            metrics: metrics, aspirations: aspirations, intentions: intentions
        )
        ForEach(clusters) { cluster in
            clusterView(cluster)
        }
        if !clusters.isEmpty, clusters.allSatisfy({ $0.state != .needsYou }) {
            Text("Nothing left to carry. See you tomorrow.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func clusterView(_ cluster: TodayGrouping.Cluster) -> some View {
        if cluster.state == .needsYou {
            ClusterCardView(cluster: cluster, runningSessions: runningSessions)
        } else {
            ClusterStubView(
                cluster: cluster,
                runningSessions: runningSessions,
                isExpanded: stubExpansion(cluster.id)
            )
        }
    }

    /// The transient expansion flag for one stub, backed by the set in
    /// `MetricListView` so sibling stubs fold independently.
    private func stubExpansion(_ id: String) -> Binding<Bool> {
        Binding(
            get: { expandedStubs.contains(id) },
            set: { expanded in
                if expanded {
                    expandedStubs.insert(id)
                } else {
                    expandedStubs.remove(id)
                }
            }
        )
    }
}
