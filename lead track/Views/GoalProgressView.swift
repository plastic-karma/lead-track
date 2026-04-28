import SwiftUI

struct GoalProgressView: View {
    let label: String
    let current: TimeInterval
    let goal: TimeInterval
    var measurementType: MeasurementType = .duration
    var unit: String?

    private var fraction: Double {
        goal > 0 ? min(current / goal, 1.0) : 0
    }

    private var isComplete: Bool {
        current >= goal
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
                .stroke(Color(.systemGray5), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    ringColor,
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

    private var ringColor: Color {
        isComplete ? .green : .orange
    }

    private var percentText: String {
        "\(Int(fraction * 100))%"
    }
}
