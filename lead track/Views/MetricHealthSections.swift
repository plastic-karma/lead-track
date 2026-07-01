import SwiftUI

/// Read-only day history for a health-linked metric. The mirror keeps one
/// session per day, so rows render straight from daily totals — no swipe
/// actions, no per-session editing.
struct HealthHistorySection: View {
    let metric: Metric
    let dailyTotals: [DailyTotal]

    private var recentDays: [DailyTotal] {
        Array(dailyTotals.suffix(14).reversed())
    }

    var body: some View {
        if !recentDays.isEmpty {
            Section("Recent Days") {
                ForEach(recentDays) { day in
                    row(day)
                }
            }
        }
    }

    private func row(_ day: DailyTotal) -> some View {
        HStack {
            Text(SessionDayGrouping.label(for: day.date))
            Spacer()
            Text(
                ValueFormatter.format(
                    day.duration,
                    type: metric.measurementType,
                    unit: metric.unit
                )
            )
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
    }
}

/// Where a health metric's numbers come from, with a pointer to the Health
/// app when nothing has arrived. HealthKit hides read denials by design, so
/// an empty mirror is the only signal there is — the hint covers both "no
/// data yet" and "access was declined".
struct HealthLinkSection: View {
    let metric: Metric
    let hasRecentData: Bool

    private static let healthAppURL = URL(string: "x-apple-health://")

    var body: some View {
        Section {
            LabeledContent("Source") {
                Label(
                    metric.healthSource?.displayName ?? "Apple Health",
                    systemImage: metric.healthSource?.defaultIcon ?? "heart"
                )
            }
            if let synced = metric.lastHealthSyncAt {
                LabeledContent("Last Synced") {
                    Text(synced, format: .relative(presentation: .named))
                }
            }
            if !hasRecentData {
                noDataHint
            }
        } header: {
            Text("Apple Health")
        } footer: {
            Text(
                "LeadStone reads this figure from Apple Health on this"
                    + " iPhone. Nothing is written back."
            )
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
