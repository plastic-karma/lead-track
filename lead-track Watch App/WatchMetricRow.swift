import SwiftUI
import WatchKit

/// One list row per metric: duration metrics toggle their timer on tap, count
/// metrics open a quick-log screen, binary metrics check today off, and
/// health-linked metrics just show today's figure.
struct WatchMetricRow: View {
    let metric: WatchMetricSnapshot

    var body: some View {
        if metric.isHealthLinked {
            WatchHealthRow(metric: metric)
        } else {
            actionRow
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch metric.measurementType {
        case .duration:
            WatchTimerRow(metric: metric)
        case .count:
            NavigationLink {
                WatchLogView(metric: metric)
            } label: {
                WatchMetricLabel(
                    metric: metric,
                    accessory: "plus.circle.fill",
                    accessoryColor: metric.displayColor
                )
            }
        case .binary:
            WatchBinaryRow(metric: metric)
        }
    }
}

/// A health-linked metric is filled by the phone from Apple Health; the
/// watch renders it read-only — sensors record it, not taps.
struct WatchHealthRow: View {
    let metric: WatchMetricSnapshot

    var body: some View {
        WatchMetricLabel(
            metric: metric,
            accessory: "heart.fill",
            accessoryColor: .pink
        )
    }
}

/// Tapping the row marks today done, or clears it when it was already done.
struct WatchBinaryRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metric: WatchMetricSnapshot

    private var isDone: Bool {
        metric.todayTotal > 0
    }

    var body: some View {
        Button(action: toggle) {
            WatchMetricLabel(
                metric: metric,
                accessory: isDone ? "checkmark.circle.fill" : "circle",
                accessoryColor: metric.displayColor
            )
        }
    }

    private func toggle() {
        sync.perform(WatchAction(kind: .toggleDay, metricID: metric.id))
        WKInterfaceDevice.current().play(.success)
    }
}
