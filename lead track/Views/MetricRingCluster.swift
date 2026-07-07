import SwiftUI

/// The bare ring-cluster drawing: an optional soft outer ring (the week), an
/// optional solid inner ring (today) that grows to full size when it rings
/// alone, and a notch riding the outer ring where the pace expectation sits.
/// Pure geometry — the caller supplies fractions and the center readout.
struct MetricRingCluster<Center: View>: View {
    let today: Double?
    let week: Double?
    let notch: Double?
    let tint: Color
    let center: Center

    private static var outerRadius: CGFloat {
        70
    }

    private static var innerRadius: CGFloat {
        52
    }

    private static var ringWidth: CGFloat {
        11
    }

    var body: some View {
        ZStack {
            if let week {
                arc(radius: Self.outerRadius, fraction: week, tint: tint.opacity(0.45))
                if let notch {
                    paceNotch(at: notch)
                }
            }
            if let today {
                arc(radius: todayRadius, fraction: today, tint: tint)
            }
            center
        }
        .frame(width: 160, height: 160)
        .animation(.snappy, value: today)
        .animation(.snappy, value: week)
    }

    /// Today's ring fills the cluster when it is the only ring.
    private var todayRadius: CGFloat {
        week == nil ? Self.outerRadius : Self.innerRadius
    }

    private func arc(
        radius: CGFloat,
        fraction: Double,
        tint: Color
    ) -> some View {
        ZStack {
            Circle()
                .stroke(Theme.inactive, lineWidth: Self.ringWidth)
            Circle()
                .trim(from: 0, to: min(max(fraction, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: Self.ringWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: fraction >= 1 ? tint.opacity(0.6) : .clear, radius: 5)
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    /// The pace expectation as a quiet notch riding the outer ring.
    private func paceNotch(at fraction: Double) -> some View {
        Capsule()
            .fill(.secondary)
            .frame(width: 2.5, height: 14)
            .offset(y: -Self.outerRadius)
            .rotationEffect(.degrees(fraction * 360))
    }
}
