import SwiftUI
import WatchKit

/// Tapping the row starts or stops the metric's timer immediately.
struct WatchTimerRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metricID: UUID
    let content: WatchMetricLabelContent

    private var isRunning: Bool {
        content.runningSince != nil
    }

    var body: some View {
        Button(action: toggle) {
            WatchMetricLabel(
                content: content,
                accessory: isRunning ? "stop.circle.fill" : "play.circle.fill",
                accessoryColor: content.displayColor
            )
        }
    }

    private func toggle() {
        let kind: WatchAction.Kind = isRunning ? .stopTimer : .startTimer
        sync.perform(WatchAction(kind: kind, metricID: metricID))
        WKInterfaceDevice.current().play(isRunning ? .stop : .start)
    }
}
