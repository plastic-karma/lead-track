import SwiftUI

struct GoalProgressView: View {
    let label: String
    let current: TimeInterval
    let goal: TimeInterval
    var measurementType: MeasurementType = .duration
    var unit: String?
    var tint: Color = .accentColor

    private var fraction: Double {
        goal > 0 ? min(current / goal, 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            progressRing
            Text(
                ValueFormatter.formatShort(
                    current, type: measurementType
                )
            )
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var progressRing: some View {
        RingGauge(fraction: fraction, tint: tint) {
            Text(percentText)
                .font(.caption2.bold())
                .monospacedDigit()
        }
        .frame(width: 44, height: 44)
    }

    private var percentText: String {
        "\(Int(fraction * 100))%"
    }
}
