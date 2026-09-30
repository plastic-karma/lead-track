import SwiftUI

/// The row's display values, independent of goal, health and sync metadata.
struct WatchMetricLabelContent: Equatable {
    let name: String
    let icon: String
    let colorName: String?
    let measurementType: MeasurementType?
    let unit: String?
    let todayTotal: Double
    let runningSince: Date?
    let countdownInterval: ClosedRange<Date>?

    init(metric: WatchMetricSnapshot) {
        name = metric.name
        icon = metric.displayIcon
        colorName = metric.colorName
        measurementType = metric.measurementType
        unit = metric.unit
        todayTotal = metric.todayTotal
        runningSince = metric.runningSince
        countdownInterval = metric.countdownInterval
    }

    var displayColor: Color {
        MetricColor.color(named: colorName)
    }

    var prominentColor: Color {
        MetricColor.prominentColor(named: colorName)
    }
}

/// Shared row layout: icon and name, a live timer or today's total, and action.
struct WatchMetricLabel: View {
    let content: WatchMetricLabelContent
    let accessory: String
    let accessoryColor: Color

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Label(content.name, systemImage: content.icon)
                    .font(.headline)
                    .lineLimit(1)
                subtitle
            }
            Spacer(minLength: 4)
            Image(systemName: accessory)
                .font(.title3)
                .foregroundStyle(accessoryColor)
        }
    }

    @ViewBuilder
    private var subtitle: some View {
        if let since = content.runningSince {
            Text(liveTimer: content.countdownInterval, countingUpFrom: since)
                .roundedDigits(.caption)
                .foregroundStyle(content.displayColor)
        } else {
            Text(todayText)
                .roundedDigits(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var todayText: String {
        if content.measurementType == .binary {
            return content.todayTotal > 0 ? "Done today" : "Not done yet"
        }
        // Unknown types from newer phones remain display-only counts.
        let total = ValueFormatter.format(
            content.todayTotal,
            type: content.measurementType ?? .count,
            unit: content.unit
        )
        return "\(total) today"
    }
}
