import SwiftUI

/// One goal's share of a segmented completion dial — its tint and how full it
/// stands (0–1; 1 fills it whole).
struct GoalDialArc: Identifiable {
    let id: Int
    let tint: Color
    let fraction: Double
}

/// A 92 pt dial divided into equal arc segments with small gaps, starting at
/// 12 o'clock. Each segment fills with its goal's color as it progresses; once
/// every goal is met the whole dial settles into the accent and a checkmark
/// replaces the count. Shared by the Today header (the day's daily goals) and
/// the Week header (the week's weekly goals), so both timescales read alike.
struct SegmentedGoalDial: View {
    let arcs: [GoalDialArc]

    private static let gapDegrees = 12.0

    private var isComplete: Bool {
        arcs.allSatisfy { $0.fraction >= 1 }
    }

    private var metCount: Int {
        arcs.count { $0.fraction >= 1 }
    }

    var body: some View {
        ZStack {
            ForEach(arcs) { arc in
                segment(at: arc.id, fraction: 1, color: Theme.inactive)
                segment(
                    at: arc.id,
                    fraction: arc.fraction,
                    color: isComplete ? .accentColor : arc.tint
                )
            }
            center
        }
        .frame(width: 92, height: 92)
        .animation(.snappy, value: arcs.map(\.fraction))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metCount) of \(arcs.count) goals done")
    }

    /// One arc: `fraction` of the segment's sweep, drawn clockwise from the
    /// segment's start. The full circle is shared equally with a small gap
    /// between neighbors, the first gap centered on 12 o'clock.
    private func segment(at index: Int, fraction: Double, color: Color) -> some View {
        let share = 360.0 / Double(arcs.count)
        let sweep = max(share - Self.gapDegrees, 4)
        let start = -90 + Self.gapDegrees / 2 + Double(index) * share
        return Circle()
            .trim(from: 0, to: sweep * min(max(fraction, 0), 1) / 360)
            .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .rotationEffect(.degrees(start))
            .padding(6)
    }

    @ViewBuilder
    private var center: some View {
        if isComplete {
            VStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text("done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 0) {
                Text("\(metCount)/\(arcs.count)")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
