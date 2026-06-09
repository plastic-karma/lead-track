import SwiftUI
import WatchKit

/// Quick entry for count metrics: adjust the amount with the crown or the
/// +/- buttons, then log it with one tap.
struct WatchLogView: View {
    @Environment(WatchSyncController.self) private var sync
    @Environment(\.dismiss) private var dismiss
    let metric: WatchMetricSnapshot
    @State private var amount = 1.0

    var body: some View {
        VStack(spacing: 12) {
            amountPicker
            logButton
        }
        .navigationTitle(metric.name)
    }

    private var amountPicker: some View {
        HStack(spacing: 8) {
            adjustButton("minus", change: -1)
            amountDisplay
            adjustButton("plus", change: 1)
        }
    }

    private var amountDisplay: some View {
        VStack(spacing: 0) {
            Text("\(Int(amount))")
                .font(.system(.title, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if let unit = metric.unit, !unit.isEmpty {
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 50)
        .focusable()
        .digitalCrownRotation(
            $amount,
            from: 1,
            through: 999,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }

    private func adjustButton(
        _ icon: String,
        change: Double
    ) -> some View {
        Button {
            amount = min(max(amount + change, 1), 999)
        } label: {
            Image(systemName: icon)
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
    }

    private var logButton: some View {
        Button(action: log) {
            Label("Log", systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private func log() {
        let action = WatchAction(
            kind: .logValue,
            metricID: metric.id,
            value: Double(Int(amount))
        )
        sync.perform(action)
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}
