import SwiftUI

/// A day-by-day bar strip for the weekly review: one capsule per day, the
/// period's biggest day fully opaque — a review asks "which day won the
/// week", not "where am I now". Empty days keep a stub so the week stays
/// readable. The full form labels each bar with its weekday initial; the
/// compact form (fixed-width bars, no labels) is the header strip's glance
/// pulse — one implementation, so the two can never drift.
struct WeekBarsView: View {
    let values: [Double]
    /// Weekday initials under the bars; empty (the compact form) hides the row.
    var labels: [String] = []
    var tint: Color = .accentColor
    /// A fixed width per bar makes the strip compact; nil lets the bars share
    /// whatever width the parent proposes.
    var barWidth: CGFloat?
    /// The gap between bars — the full-width form breathes at 8, the compact
    /// glance sits at 3.
    var spacing: CGFloat = 8

    private var peak: Double {
        max(values.max() ?? 0, 1)
    }

    private var peakIndex: Int? {
        guard let maxValue = values.max(), maxValue > 0 else { return nil }
        return values.firstIndex(of: maxValue)
    }

    var body: some View {
        VStack(spacing: 6) {
            bars
            if !labels.isEmpty {
                labelRow
            }
        }
        .accessibilityHidden(true)
    }

    private var bars: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(values.indices, id: \.self) { index in
                    bar(at: index, fullHeight: geometry.size.height)
                }
            }
        }
    }

    private func bar(at index: Int, fullHeight: CGFloat) -> some View {
        Capsule()
            .fill(tint.opacity(index == peakIndex ? 1 : 0.35))
            .frame(width: barWidth, height: max(fullHeight * values[index] / peak, 3))
            .frame(maxWidth: barWidth == nil ? .infinity : nil, maxHeight: .infinity, alignment: .bottom)
    }

    private var labelRow: some View {
        HStack(spacing: spacing) {
            ForEach(labels.indices, id: \.self) { index in
                Text(labels[index])
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

extension WeekBarsView {
    /// Narrow weekday symbols for `count` consecutive days starting at `start`,
    /// matching the order of a review's daily series.
    static func weekdayLabels(
        from start: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [String] {
        (0 ..< count).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: start) ?? start
            return day.formatted(.dateTime.weekday(.narrow))
        }
    }
}
