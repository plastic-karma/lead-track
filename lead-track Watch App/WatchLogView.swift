import SwiftUI
import WatchKit

/// Quick count entry using the crown or +/- buttons, then one tap to log.
struct WatchLogView: View {
    @Environment(WatchSyncController.self) private var sync
    @Environment(\.dismiss) private var dismiss
    let metricID: UUID
    let name: String
    let unit: String?
    let tint: Color
    @State private var amount = 1.0

    var body: some View {
        VStack(spacing: 12) {
            WatchAmountPicker(name: name, unit: unit, amount: $amount)
            Button(action: log) {
                Label("Log", systemImage: "checkmark")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        }
        .navigationTitle(name)
    }

    private func log() {
        let action = WatchAction(
            kind: .logValue,
            metricID: metricID,
            value: Double(Int(amount))
        )
        sync.perform(action)
        WKInterfaceDevice.current().play(.success)
        dismiss()
    }
}

private struct WatchAmountPicker: View {
    let name: String
    let unit: String?
    @Binding var amount: Double

    /// Shared bounds keep the crown, buttons and accessibility in agreement.
    private static let amountRange: ClosedRange<Double> = 1 ... 999

    var body: some View {
        HStack(spacing: 8) {
            adjustButton("minus", change: -1)
            amountDisplay
            adjustButton("plus", change: 1)
        }
    }

    private var amountDisplay: some View {
        VStack(spacing: 0) {
            Text(Int(amount), format: .number)
                .roundedDigits(.title, weight: .semibold)
            if let unit, !unit.isEmpty {
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
        .accessibilityLabel(name)
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
        let value = Int(amount).formatted()
        guard let unit, !unit.isEmpty else { return value }
        return "\(value) \(unit)"
    }

    private func adjust(by change: Double) {
        amount = min(
            max(amount + change, Self.amountRange.lowerBound),
            Self.amountRange.upperBound
        )
    }

    private func adjustButton(_ icon: String, change: Double) -> some View {
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
}
