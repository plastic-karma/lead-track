import SwiftData
import SwiftUI

/// A resting, done, or self-filling cluster compressed to one quiet line —
/// plus its intention rows, which never fold. Tapping the header (or its
/// chevron) expands the cluster inline into its full card; the expansion is
/// per-cluster, transient, and never persisted. The screen earns its calm as
/// the day is completed.
struct ClusterStubView: View {
    let cluster: TodayGrouping.Cluster
    let runningSessions: [Session]
    @Binding var isExpanded: Bool

    var body: some View {
        if isExpanded {
            ClusterCardView(cluster: cluster, runningSessions: runningSessions) {
                withAnimation(.snappy) { isExpanded = false }
            }
        } else {
            stub
        }
    }

    private var stub: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.snappy) { isExpanded = true }
            } label: {
                header
            }
            .buttonStyle(.plain)
            .accessibilityHint("Expand")
            if !cluster.intentions.isEmpty {
                Divider()
                intentionRows
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, cluster.intentions.isEmpty ? 4 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clusterCardSurface()
    }

    private var intentionRows: some View {
        let intentions = cluster.intentions
        return ForEach(Array(intentions.enumerated()), id: \.element.id) { index, intention in
            ClusterIntentionRow(intention: intention)
            if index < intentions.count - 1 {
                Divider()
                    .padding(.leading, 42)
            }
        }
    }
}

// MARK: - Header

extension ClusterStubView {
    private var header: some View {
        ClusterHeaderLabel(
            cluster: cluster,
            bottomPadding: cluster.intentions.isEmpty ? 12 : 10
        ) {
            statusLine
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Status Line

extension ClusterStubView {
    /// The one-line reason this cluster rests as a stub.
    @ViewBuilder
    private var statusLine: some View {
        switch cluster.state {
        case .done:
            doneStatus
        case .resting:
            restingStatus
        case .selfFilling:
            selfFillingStatus
        case .needsYou:
            EmptyView()
        }
    }

    private var doneStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(cluster.aspiration?.displayColor ?? .accentColor)
            Text(TodayGrouping.doneSummary(for: cluster.metrics))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var restingStatus: some View {
        if let date = TodayGrouping.nextGoalDate(for: cluster.metrics) {
            Text("resting until \(date.formatted(.dateTime.weekday(.wide)))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    /// "342 kcal · fills itself from Health" — the value in rounded
    /// semibold primary ink, the provenance quiet.
    private var selfFillingStatus: some View {
        let line = if let value = selfFillingValue {
            Text(value)
                .font(.system(.caption2, design: .rounded).weight(.semibold))
                .foregroundStyle(.primary)
                + Text(" · fills itself from Health")
                .foregroundStyle(.secondary)
        } else {
            Text("fills itself from Health")
                .foregroundStyle(.secondary)
        }
        return line
            .font(.caption2)
            .lineLimit(1)
    }

    /// Today's mirrored figure when the stub holds a single health metric;
    /// several can't share one number, so the line stays wordless.
    private var selfFillingValue: String? {
        guard cluster.metrics.count == 1, let metric = cluster.metrics.first
        else { return nil }
        let today = SessionStatistics.todayTotal(from: metric.sessions)
        return ValueFormatter.format(today, type: metric.measurementType, unit: metric.unit)
    }
}
