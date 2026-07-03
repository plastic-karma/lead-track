import SwiftUI

/// The aspiration-first arrangement of Today's open cards: each cluster opens
/// with its aspiration's title and why line — a reason before the numbers —
/// and the metrics serving no aspiration close the list under "Unaligned
/// effort". That section's existence is the whole nudge: no badge, no CTA.
extension MetricListView {
    @ViewBuilder
    var groupedMetricSections: some View {
        let split = TodayGrouping.groups(metrics: leftMetrics, aspirations: aspirations)
        ForEach(split.groups) { group in
            groupHeader(group.aspiration)
            ForEach(group.metrics) { metricCard($0) }
        }
        if !split.unaligned.isEmpty {
            unalignedHeader
            ForEach(split.unaligned) { metricCard($0) }
        }
    }

    /// The aspiration's name and why line, tappable through to its screen.
    private func groupHeader(_ aspiration: Aspiration) -> some View {
        NavigationLink(value: aspiration) {
            VStack(alignment: .leading, spacing: 6) {
                Divider()
                HStack(spacing: 6) {
                    Image(systemName: aspiration.displayIcon)
                        .font(.caption2)
                    Text(aspiration.title)
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .kerning(0.5)
                }
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                if !aspiration.detail.isEmpty {
                    Text(aspiration.detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.top, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var unalignedHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Unaligned Effort")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
                .padding(.top, 8)
            Text("Not serving any aspiration yet")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }
}
