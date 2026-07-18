import SwiftData
import SwiftUI

/// Today's smart-ordered cluster arrangement (see `TodayGrouping.clusters`):
/// every cluster is one collapsible card, all folded to their one-line stubs
/// by default so the screen opens calm and focused; tap a header to expand a
/// cluster inline. The neediest clusters sort first until the user drags a
/// card into place — manual order then holds permanently — and once nothing
/// needs the user anymore, a closing caption sends the day off. When the
/// header chevrons browse an earlier day, the same arrangement replays that
/// day with no live timers and no send-off — but its rows still record,
/// onto the browsed day, so a forgotten log can be added after the fact.
extension MetricListView {
    @ViewBuilder
    var clusterSections: some View {
        let day = TodayGrouping.day(back: daysBack)
        let clusters = TodayGrouping.clusters(
            metrics: metrics, aspirations: aspirations, intentions: intentions, now: day
        )
        ForEach(clusters) { cluster in
            ClusterStubView(
                cluster: cluster,
                runningSessions: daysBack == 0 ? runningSessions : [],
                day: day,
                isExpanded: expansion(of: cluster)
            )
            .aspirationReorderable(
                id: cluster.aspiration == nil ? nil : cluster.id,
                draggingID: $draggingClusterID
            ) { draggedID, targetID in
                move(draggedID, over: targetID, visible: clusters)
            }
        }
        if daysBack == 0, !clusters.isEmpty, clusters.allSatisfy({ $0.state != .needsYou }) {
            Text("Nothing left to carry. See you tomorrow.")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.75))
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
    }

    /// One hover step of a cluster drag: the first ever seeds the ranks from
    /// the on-screen smart order (so nothing jumps but the dragged card),
    /// then the ranks are rewritten and saved. The unaligned pseudo-cluster
    /// never takes part — it always trails.
    private func move(
        _ draggedID: String,
        over targetID: String,
        visible clusters: [TodayGrouping.Cluster]
    ) {
        withAnimation(.snappy) {
            AspirationReorder.applyMove(
                all: aspirations,
                visibleIDs: clusters.compactMap { $0.aspiration == nil ? nil : $0.id },
                draggedID: draggedID,
                targetID: targetID
            )
            try? modelContext.save()
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
