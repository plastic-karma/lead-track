import SwiftUI

/// A labeled day-by-day bar strip for the weekly review: one capsule per day
/// with its weekday initial underneath. Unlike `SparklineView`, which singles
/// out today, this strip singles out the period's biggest day — a review asks
/// "which day won the week", not "where am I now". Empty days keep a stub so
/// the week stays readable.
struct WeekBarsView: View {
    let values: [Double]
    let labels: [String]
    var tint: Color = .accentColor

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
            labelRow
        }
        .accessibilityHidden(true)
    }

    private var bars: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(values.indices, id: \.self) { index in
                    bar(at: index, fullHeight: geometry.size.height)
                }
            }
        }
    }

    private func bar(at index: Int, fullHeight: CGFloat) -> some View {
        Capsule()
            .fill(tint.opacity(index == peakIndex ? 1 : 0.35))
            .frame(height: max(fullHeight * values[index] / peak, 3))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var labelRow: some View {
        HStack(spacing: 8) {
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
