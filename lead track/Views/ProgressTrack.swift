import SwiftUI

/// A rounded progress track with a tinted fill that lifts into a soft glow the
/// moment the goal is reached — the small celebration the old hairline bars
/// never gave. The height comes from the caller's frame.
struct ProgressTrack: View {
    let fraction: Double
    var tint: Color = .accentColor

    private var isComplete: Bool {
        fraction >= 1
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.inactive)
                Capsule()
                    .fill(tint)
                    .frame(width: fillWidth(geo.size.width))
                    .shadow(
                        color: isComplete ? tint.opacity(0.6) : .clear,
                        radius: 5
                    )
            }
        }
        .animation(.snappy, value: fraction)
    }

    private func fillWidth(_ available: CGFloat) -> CGFloat {
        guard fraction > 0 else { return 0 }
        return max(available * fraction, 4)
    }
}
