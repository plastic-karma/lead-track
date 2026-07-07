import SwiftUI

/// Read-only day history for a health-linked metric, as flat rows for the
/// History fold. The mirror keeps one session per day, so rows render
/// straight from daily totals — no context menus, no per-session editing.
struct HealthHistoryRows: View {
    let metric: Metric
    let dailyTotals: [DailyTotal]

    /// The trailing days the fold previews, newest first — shared with the
    /// fold row so its "n days" label always matches the rows below.
    static func days(from totals: [DailyTotal]) -> [DailyTotal] {
        Array(totals.suffix(14).reversed())
    }

    var body: some View {
        ForEach(Self.days(from: dailyTotals)) { day in
            row(day)
        }
    }

    private func row(_ day: DailyTotal) -> some View {
        HStack {
            Text(SessionDayGrouping.label(for: day.date))
                .font(.subheadline)
            Spacer()
            Text(
                ValueFormatter.format(
                    day.duration,
                    type: metric.measurementType,
                    unit: metric.unit
                )
            )
            .numeralStyle(.stat)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 40)
    }
}

/// The Apple Health fold's expanded body: where a mirrored metric's numbers
/// come from, with a pointer to the Health app when nothing has arrived.
/// HealthKit hides read denials by design, so an empty mirror is the only
/// signal there is — the hint covers both "no data yet" and "access was
/// declined".
struct HealthFoldContent: View {
    let metric: Metric
    let hasRecentData: Bool

    private static let healthAppURL = URL(string: "x-apple-health://")

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            sourceRow
            syncedRow
            if !hasRecentData {
                noDataHint
            }
            Text(
                "LeadStone reads this figure from Apple Health on this"
                    + " iPhone. Nothing is written back."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private var sourceRow: some View {
        LabeledContent("Source") {
            Label(
                metric.healthSource?.displayName ?? "Apple Health",
                systemImage: metric.healthSource?.defaultIcon ?? "heart"
            )
        }
        .font(.subheadline)
    }

    @ViewBuilder
    private var syncedRow: some View {
        if let synced = metric.lastHealthSyncAt {
            LabeledContent("Last Synced") {
                Text(synced, format: .relative(presentation: .named))
            }
            .font(.subheadline)
        }
    }

    private var noDataHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("No data in the last 30 days")
                .font(.subheadline.weight(.medium))
            Text(
                "If you declined access, allow reading under Health →"
                    + " Profile → Privacy → Apps → LeadStone, then sync again."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            if let url = Self.healthAppURL {
                Link("Open Health", destination: url)
                    .font(.caption.weight(.medium))
            }
        }
        .padding(.vertical, 2)
    }
}
