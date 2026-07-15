// iOS-gated to match Theme.inactive's availability: the ring's only
// consumers are the app and the home-screen widget, while Shared/ also
// compiles into the watch targets and the macOS overlay.
#if canImport(SwiftUI) && os(iOS)
import SwiftUI

/// The shared progress ring: a neutral track plus a trimmed, round-capped
/// arc with a center label slot. `GoalProgressView` and the scoreboard
/// widget's mini rings draw through this one shape so their geometry can't
/// drift apart.
struct RingGauge<Label: View>: View {
    let fraction: Double
    let tint: Color
    var lineWidth: CGFloat = 4
    @ViewBuilder var label: () -> Label

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.inactive, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            label()
        }
    }
}
#endif
