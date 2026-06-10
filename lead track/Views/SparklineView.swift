import SwiftUI

/// A minimal bar sparkline for a short window of daily totals. All bars share
/// one hue; the last bar (today) is fully opaque so the current day stands
/// out, and empty days keep a small stub so the window stays readable.
struct SparklineView: View {
    let values: [Double]

    private var peak: Double {
        max(values.max() ?? 0, 1)
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(values.indices, id: \.self) { index in
                    bar(at: index, fullHeight: geometry.size.height)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(at index: Int, fullHeight: CGFloat) -> some View {
        let isToday = index == values.count - 1
        return Capsule()
            .fill(Color.accentColor.opacity(isToday ? 1 : 0.35))
            .frame(height: max(fullHeight * values[index] / peak, 3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}
