import SwiftUI
import WatchKit

/// One list row per metric: duration metrics toggle their timer on tap, count
/// metrics open a quick-log screen, and binary metrics check today off.
struct WatchMetricRow: View {
    let metric: WatchMetricSnapshot

    var body: some View {
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
