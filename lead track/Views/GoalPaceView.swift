import SwiftUI

/// A banner reporting whether the week is ahead of, on, or behind the pace
/// needed to reach the weekly goal, with a projected end-of-week total.
struct GoalPaceView: View {
    let pace: GoalPace
    var measurementType: MeasurementType = .duration
    var unit: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Text

extension GoalPaceView {
    private var headline: String {
        switch pace.status {
        case .achieved: "Weekly goal reached"
        case .onTrack: "On track for your weekly goal"
        case .ahead: "\(deltaText) ahead of pace"
        case .behind: "\(deltaText) behind pace"
        }
    }

    private var detail: String {
        switch pace.status {
        case .achieved: achievedDetail
        default: projectionDetail
        }
    }

    private var deltaText: String {
        ValueFormatter.formatShort(abs(pace.delta), type: measurementType)
    }

    private var achievedDetail: String {
        let total = ValueFormatter.format(pace.actual, type: measurementType, unit: unit)
        let goal = ValueFormatter.format(pace.goal, type: measurementType, unit: unit)
        return "\(total) of \(goal) this week"
    }

    private var projectionDetail: String {
        let projected = ValueFormatter.format(pace.projectedTotal, type: measurementType, unit: unit)
        let goal = ValueFormatter.format(pace.goal, type: measurementType, unit: unit)
        return "On pace for \(projected) · goal \(goal)"
    }
}

// MARK: - Style

extension GoalPaceView {
    private var symbol: String {
        switch pace.status {
        case .achieved: "checkmark.seal.fill"
        case .ahead: "gauge.with.dots.needle.67percent"
        case .onTrack: "gauge.with.dots.needle.50percent"
        case .behind: "gauge.with.dots.needle.33percent"
        }
    }

    private var tint: Color {
        switch pace.status {
        case .achieved, .ahead: .green
        case .onTrack: .orange
        case .behind: .red
        }
    }
}
