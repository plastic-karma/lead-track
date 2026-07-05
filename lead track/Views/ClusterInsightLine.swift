import SwiftUI

/// The quiet one-line reading a full cluster card closes with — deterministic
/// and computed locally, never a warning tone, red never used. Unmet goals
/// say what little remains; resting clusters say when they return; health
/// clusters say the day fills itself.
struct ClusterInsightLine: View {
    let reading: ClusterInsight

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: reading.symbol)
                .font(.caption)
                .foregroundStyle(reading.tint)
            line
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.top, 10)
        .padding(.bottom, 12)
    }

    /// The key figure carries the aspiration's ink; the rest stays quiet.
    private var line: Text {
        Text(reading.prefix).foregroundStyle(.secondary)
            + Text(reading.figure).fontWeight(.semibold).foregroundStyle(reading.tint)
            + Text(reading.suffix).foregroundStyle(.secondary)
    }
}

/// One cluster's insight content, or nil when the card has nothing quiet to
/// say (done clusters rest on their rows; a needy cluster without a
/// measurable remainder stays silent).
struct ClusterInsight {
    let symbol: String
    let tint: Color
    let prefix: String
    let figure: String
    let suffix: String

    static func make(for cluster: TodayGrouping.Cluster) -> ClusterInsight? {
        switch cluster.state {
        case .needsYou:
            return remaining(for: cluster)
        case .resting:
            return resting(for: cluster)
        case .selfFilling:
            return health
        case .done:
            return nil
        }
    }
}

// MARK: - Readings

extension ClusterInsight {
    private static func ink(of cluster: TodayGrouping.Cluster, fallback: Metric?) -> Color {
        cluster.aspiration?.displayColor
            ?? fallback.map(\.displayColor)
            ?? .accentColor
    }

    /// "1m 18s more brings today home" — the neediest unmet metric's gap.
    private static func remaining(for cluster: TodayGrouping.Cluster) -> ClusterInsight? {
        guard let metric = TodayGrouping.neediestMetric(in: cluster.metrics),
              let remaining = TodayGrouping.remainingToday(for: metric)
        else { return nil }
        let amount = ValueFormatter.format(
            remaining, type: metric.measurementType, unit: metric.unit
        )
        return ClusterInsight(
            symbol: "clock",
            tint: ink(of: cluster, fallback: metric),
            prefix: "",
            figure: "\(amount) more",
            suffix: " brings today home"
        )
    }

    /// "Resting until Monday — 2 left this week"; the second clause only
    /// when a counted intention still has ticks to give.
    private static func resting(for cluster: TodayGrouping.Cluster) -> ClusterInsight? {
        guard let date = TodayGrouping.nextGoalDate(for: cluster.metrics)
        else { return nil }
        let weekday = date.formatted(.dateTime.weekday(.wide))
        let tint = ink(of: cluster, fallback: cluster.metrics.first)
        guard let left = openTickCount(in: cluster) else {
            return ClusterInsight(
                symbol: "checkmark.circle", tint: tint,
                prefix: "Resting until \(weekday)", figure: "", suffix: ""
            )
        }
        return ClusterInsight(
            symbol: "checkmark.circle", tint: tint,
            prefix: "Resting until \(weekday) — ",
            figure: "\(left) left",
            suffix: " this week"
        )
    }

    private static func openTickCount(in cluster: TodayGrouping.Cluster) -> Int? {
        cluster.intentions.lazy
            .filter { $0.kind == .counted }
            .compactMap { intention -> Int? in
                guard let progress = IntentionProgress.compute(for: intention)
                else { return nil }
                let left = Int(progress.target - progress.value)
                return left > 0 ? left : nil
            }
            .first
    }

    /// "Fills itself from Apple Health — nothing to do here."
    private static var health: ClusterInsight {
        ClusterInsight(
            symbol: "heart.fill",
            tint: .pink,
            prefix: "Fills itself from Apple Health — nothing to do here",
            figure: "",
            suffix: ""
        )
    }
}
