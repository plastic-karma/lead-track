import SwiftUI

/// A finished metric collapsed to a single quiet row in the "Done Today"
/// section: a tinted check, the name, and today's value. Tapping expands it
/// back into the full card so you can still act on it — log more, or start
/// another session — without leaving the dashboard.
struct DoneMetricRow: View {
    let metric: Metric
    let runningSession: Session?
    @State private var expanded = false

    var body: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { expanded.toggle() }
            } label: {
                summary
            }
            .buttonStyle(.plain)
            if expanded {
                NavigationLink(value: metric) {
                    MetricCardView(metric: metric, runningSession: runningSession)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var summary: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(metric.displayColor)
            Text(metric.name)
                .font(.headline)
            Spacer()
            Text(valueText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Image(systemName: "chevron.down")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .rotationEffect(.degrees(expanded ? 180 : 0))
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardBackground)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint(expanded ? "Collapse" : "Expand")
    }

    private var valueText: String {
        ValueFormatter.format(
            SessionStatistics.todayTotal(from: metric.sessions),
            type: metric.measurementType,
            unit: metric.unit
        )
    }
}
