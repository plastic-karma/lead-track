import SwiftUI
import WatchKit

/// One list row per metric: duration metrics toggle their timer on tap, count
/// metrics log one or open a quick-log screen per their log style, binary
/// metrics check today off, and health-linked metrics just show today's
/// figure.
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
            WatchCountRow(metric: metric)
        case .binary:
            WatchBinaryRow(metric: metric)
        case nil:
            // A snapshot from a newer phone can carry a measurement type
            // this build doesn't know. Render it read-only rather than
            // guessing what a tap should record.
            WatchMetricLabel(
                metric: metric,
                accessory: "circle.dashed",
                accessoryColor: .secondary
            )
        }
    }
}

/// A count row follows the metric's log style: +1 metrics log a single unit
/// right on the tap, ask-amount metrics push the crown-driven quick-log
/// screen.
struct WatchCountRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metric: WatchMetricSnapshot

    var body: some View {
        if metric.countLogStyle == .incrementByOne {
            Button(action: logOne) {
                label
            }
        } else {
            NavigationLink {
                WatchLogView(metric: metric)
            } label: {
                label
            }
        }
    }

    private var label: some View {
        WatchMetricLabel(
            metric: metric,
            accessory: "plus.circle.fill",
            accessoryColor: metric.displayColor
        )
    }

    private func logOne() {
        sync.perform(WatchAction(kind: .logValue, metricID: metric.id, value: 1))
        WKInterfaceDevice.current().play(.success)
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
