import SwiftData
import SwiftUI

/// One aspiration's full cluster card on Today — the expanded form of every
/// collapsible cluster (see `ClusterStubView`): the aspiration is the card,
/// its metrics are rows inside it — living rows that act in place, done rows
/// resting quietly where they are — followed by this week's intentions and a
/// closing insight line. The header folds the cluster back to one line.
struct ClusterCardView: View {
    let cluster: TodayGrouping.Cluster
    let runningSessions: [Session]
    /// The header carries the rotated chevron and folds the cluster back to
    /// its stub.
    let onCollapse: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            rows
            if let reading = insight {
                ClusterInsightLine(reading: reading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clusterCardSurface()
    }

    private var insight: ClusterInsight? {
        ClusterInsight.make(for: cluster)
    }
}

// MARK: - Header

extension ClusterCardView {
    /// The full card's opening line: folds the cluster back to its stub (the
    /// rotated chevron says so). The aspiration itself is reached from the
    /// Aspirations tab, not from here.
    private var header: some View {
        Button(action: onCollapse) {
            headerLabel
        }
        .buttonStyle(.plain)
        .accessibilityHint("Collapse")
    }

    private var headerLabel: some View {
        ClusterHeaderLabel(cluster: cluster) {
            if let why {
                Text(why)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(180))
        }
    }

    private var why: String? {
        guard let aspiration = cluster.aspiration else {
            return "Not serving any aspiration yet"
        }
        return aspiration.detail.isEmpty ? nil : aspiration.detail
    }
}

// MARK: - Rows

extension ClusterCardView {
    /// Metric rows in their stored order — done rows fold in place, never
    /// re-sorted — then the intention rows, with an inset hairline between
    /// neighbors (and before the insight line when one closes the card).
    private var rows: some View {
        DividedRows(items: rowItems, dividerAfterLast: insight != nil) { item in
            rowView(item)
        }
    }

    private enum RowItem: Identifiable {
        case metric(Metric)
        case intention(Intention)

        var id: String {
            switch self {
            case let .metric(metric):
                "metric-\(metric.stableIdentity)"
            case let .intention(intention):
                "intention-\(intention.stableIdentity)"
            }
        }
    }

    private var rowItems: [RowItem] {
        cluster.metrics.map(RowItem.metric) + cluster.intentions.map(RowItem.intention)
    }

    @ViewBuilder
    private func rowView(_ item: RowItem) -> some View {
        switch item {
        case let .metric(metric):
            ClusterMetricRow(metric: metric, runningSession: runningSession(for: metric))
        case let .intention(intention):
            ClusterIntentionRow(intention: intention)
        }
    }

    private func runningSession(for metric: Metric) -> Session? {
        let id = metric.persistentModelID
        return runningSessions.first { $0.metric?.persistentModelID == id }
    }
}

// MARK: - Header Label

/// The identity half every cluster header shares — icon and uppercase title
/// in the aspiration's ink, then the caller's right side (a why line, a
/// status reading, a chevron). The unaligned pseudo-cluster stays
/// deliberately unhighlighted: its quietness is the whole nudge.
struct ClusterHeaderLabel<Trailing: View>: View {
    let cluster: TodayGrouping.Cluster
    var bottomPadding: CGFloat = 10
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(iconTint)
            }
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.5)
                .foregroundStyle(titleTint)
                .lineLimit(1)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 12)
        .padding(.bottom, bottomPadding)
        .contentShape(Rectangle())
    }
}

// MARK: - Header Identity

extension ClusterHeaderLabel {
    /// A lone unaligned metric titles its own card; several share the
    /// existing "Unaligned Effort" language.
    private var title: String {
        if let aspiration = cluster.aspiration { return aspiration.title }
        guard let metric = soleMetric else { return "Unaligned Effort" }
        return metric.name
    }

    private var icon: String? {
        cluster.aspiration?.displayIcon ?? soleMetric?.displayIcon
    }

    private var iconTint: Color {
        cluster.aspiration?.displayColor ?? soleMetric?.displayColor ?? .secondary
    }

    private var titleTint: Color {
        cluster.aspiration == nil ? .secondary : iconTint
    }

    private var soleMetric: Metric? {
        cluster.metrics.count == 1 ? cluster.metrics.first : nil
    }
}

// MARK: - Surface

extension View {
    /// The cluster card's shell: the standard elevated card surface without
    /// `cardSurface()`'s uniform padding — cluster rows manage their own.
    func clusterCardSurface() -> some View {
        background(Theme.cardShape())
    }
}
