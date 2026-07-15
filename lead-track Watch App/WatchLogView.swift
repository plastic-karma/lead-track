import SwiftUI
import WatchKit

/// Quick entry for count metrics: adjust the amount with the crown or the
/// +/- buttons, then log it with one tap.
struct WatchLogView: View {
    @Environment(WatchSyncController.self) private var sync
    @Environment(\.dismiss) private var dismiss
    let metric: WatchMetricSnapshot
    @State private var amount = 1.0

    /// One set of bounds for the crown, the +/- buttons, and the
    /// accessibility adjustable action, so they can't diverge.
    private static let amountRange: ClosedRange<Double> = 1 ... 999

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
                .roundedDigits(.title, weight: .semibold)
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
            from: Self.amountRange.lowerBound,
            through: Self.amountRange.upperBound,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(metric.name)
        .accessibilityValue(accessibilityAmount)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: adjust(by: 1)
            case .decrement: adjust(by: -1)
            @unknown default: break
            }
        }
    }

    private var accessibilityAmount: String {
        guard let unit = metric.unit, !unit.isEmpty else { return "\(Int(amount))" }
        return "\(Int(amount)) \(unit)"
    }

    private func adjust(by change: Double) {
        amount = min(
            max(amount + change, Self.amountRange.lowerBound),
            Self.amountRange.upperBound
        )
    }

    private func adjustButton(
        _ icon: String,
        change: Double
    ) -> some View {
        Button {
            adjust(by: change)
        } label: {
            Image(systemName: icon)
                .font(.headline)
        }
        .buttonStyle(.bordered)
        .clipShape(Circle())
        .accessibilityLabel(change > 0 ? "Increase amount" : "Decrease amount")
    }

    private var logButton: some View {
        Button(action: log) {
            Label("Log", systemImage: "checkmark")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(metric.prominentColor)
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
