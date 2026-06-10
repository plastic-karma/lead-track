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
        ZStack {
            Circle()
                .stroke(Theme.inactive, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    tint,
                    style: StrokeStyle(
                        lineWidth: 4, lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
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
