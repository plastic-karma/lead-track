import SwiftUI
import WatchKit

/// Tapping the row starts or stops the metric's timer immediately.
struct WatchTimerRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metric: WatchMetricSnapshot

    private var isRunning: Bool {
        metric.runningSince != nil
    }

    var body: some View {
        Button(action: toggle) {
            WatchMetricLabel(
                metric: metric,
                accessory: isRunning ? "stop.circle.fill" : "play.circle.fill",
                accessoryColor: isRunning
                    ? .red
                    : MetricColor.color(named: metric.colorName)
            )
        }
    }

    private func toggle() {
        let kind: WatchAction.Kind = isRunning ? .stopTimer : .startTimer
        sync.perform(WatchAction(kind: kind, metricID: metric.id))
        WKInterfaceDevice.current().play(isRunning ? .stop : .start)
    }
}
