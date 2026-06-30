import SwiftUI

/// Shared row layout: metric icon and name, a live elapsed timer or today's
/// total underneath, and a trailing action glyph.
struct WatchMetricLabel: View {
    let metric: WatchMetricSnapshot
    let accessory: String
    let accessoryColor: Color

    var body: some View {
        HStack(spacing: 6) {
            details
            Spacer(minLength: 4)
            Image(systemName: accessory)
                .font(.title3)
                .foregroundStyle(accessoryColor)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(metric.name, systemImage: metric.icon ?? defaultIcon)
                .font(.headline)
                .lineLimit(1)
            subtitle
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let since = metric.runningSince {
            Text(liveTimer: metric.countdownInterval, countingUpFrom: since)
                .roundedDigits(.caption)
                .foregroundStyle(metric.displayColor)
        } else {
            Text(todayText)
                .roundedDigits(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var todayText: String {
        if metric.measurementType == .binary {
            return metric.todayTotal > 0 ? "Done today" : "Not done yet"
        }
        let total = ValueFormatter.format(
            metric.todayTotal,
            type: metric.measurementType,
            unit: metric.unit
        )
        return "\(total) today"
    }

    private var defaultIcon: String {
        switch metric.measurementType {
        case .duration: "timer"
        case .count: "number"
        case .binary: "checkmark.circle"
        }
    }
}
