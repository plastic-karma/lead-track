import SwiftUI
import WatchKit

/// One list row per metric. Goal and sync metadata do not invalidate the row.
struct WatchMetricRow: View {
    private let metricID: UUID
    private let content: WatchMetricLabelContent
    private let isHealthLinked: Bool
    private let countLogStyle: CountLogStyle

    init(metric: WatchMetricSnapshot) {
        metricID = metric.id
        content = WatchMetricLabelContent(metric: metric)
        isHealthLinked = metric.isHealthLinked
        countLogStyle = metric.countLogStyle
    }

    var body: some View {
        // Keep one root for List identity even when the action kind changes.
        VStack {
            if isHealthLinked {
                WatchMetricLabel(content: content, accessory: "heart.fill", accessoryColor: .pink)
            } else {
                actionRow
            }
        }
    }

    @ViewBuilder
    private var actionRow: some View {
        switch content.measurementType {
        case .duration:
            WatchTimerRow(metricID: metricID, content: content)
        case .count:
            WatchCountRow(metricID: metricID, content: content, logStyle: countLogStyle)
        case .binary:
            WatchBinaryRow(metricID: metricID, content: content)
        case nil:
            // A newer phone's unknown type remains read-only.
            WatchMetricLabel(content: content, accessory: "circle.dashed", accessoryColor: .secondary)
        }
    }
}

/// +1 metrics act immediately; ask-amount metrics push crown-driven entry.
private struct WatchCountRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metricID: UUID
    let content: WatchMetricLabelContent
    let logStyle: CountLogStyle

    var body: some View {
        if logStyle == .incrementByOne {
            Button(action: logOne) { label }
        } else {
            NavigationLink {
                WatchLogView(
                    metricID: metricID,
                    name: content.name,
                    unit: content.unit,
                    tint: content.prominentColor
                )
            } label: {
                label
            }
        }
    }

    private var label: some View {
        WatchMetricLabel(
            content: content,
            accessory: "plus.circle.fill",
            accessoryColor: content.displayColor
        )
    }

    private func logOne() {
        sync.perform(WatchAction(kind: .logValue, metricID: metricID, value: 1))
        WKInterfaceDevice.current().play(.success)
    }
}

/// Tapping marks today done, or clears it when it was already done.
private struct WatchBinaryRow: View {
    @Environment(WatchSyncController.self) private var sync
    let metricID: UUID
    let content: WatchMetricLabelContent

    var body: some View {
        Button(action: toggle) {
            WatchMetricLabel(
                content: content,
                accessory: content.todayTotal > 0 ? "checkmark.circle.fill" : "circle",
                accessoryColor: content.displayColor
            )
        }
    }

    private func toggle() {
        sync.perform(WatchAction(kind: .toggleDay, metricID: metricID))
        WKInterfaceDevice.current().play(.success)
    }
}
