import SwiftUI

/// A ring split into one segment per goal, filling green as each goal is met.
/// The met/total count sits in the center so you can see how many goals are
/// done for the day or week — and whether you're finished — at a glance.
struct GoalTrackerRing: View {
    let label: String
    let summary: GoalSummary

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            ring
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var ring: some View {
        ZStack {
            ForEach(0 ..< summary.total, id: \.self, content: segment)
            center
        }
        .frame(width: 52, height: 52)
    }

    private func segment(_ index: Int) -> some View {
        let span = 1.0 / Double(summary.total)
        let gap = summary.total > 1 ? 0.05 : 0.0
        return Circle()
            .trim(
                from: Double(index) * span + gap / 2,
                to: Double(index + 1) * span - gap / 2
            )
            .stroke(
                index < summary.met ? Color.green : Color(.systemGray5),
                style: StrokeStyle(lineWidth: 5, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }

    @ViewBuilder
    private var center: some View {
        if summary.isComplete {
            Image(systemName: "checkmark")
                .font(.callout.bold())
                .foregroundStyle(.green)
        } else {
            Text("\(summary.met)/\(summary.total)")
                .font(.caption.bold())
                .monospacedDigit()
        }
    }

    private var caption: String {
        summary.isComplete ? "All done" : "\(summary.met) of \(summary.total)"
    }
}
