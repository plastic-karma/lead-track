import SwiftUI

struct CalendarHeatmapView: View {
    let dailyTotals: [DailyTotal]
    var tint: Color = .accentColor

    /// How many trailing weeks the grid shows — internal so the Activity
    /// fold's "16 weeks" label can never drift from the grid itself.
    static let weekCount = 16
    private static let cellSize: CGFloat = 16
    private static let spacing: CGFloat = 3

    private let calendar = Calendar.current

    var body: some View {
        // Built once per render and passed down — color(for:) runs for every
        // one of the grid's 112 cells.
        let scale = intensityScale
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                grid(scale)
            }
            legend
        }
        .padding(.vertical, 4)
    }

    /// The day → total lookup and its peak, the two aggregates every cell
    /// color reads.
    private struct IntensityScale {
        let totalsByDay: [Date: TimeInterval]
        let maxValue: TimeInterval
    }
}

// MARK: - Grid

extension CalendarHeatmapView {
    private func grid(_ scale: IntensityScale) -> some View {
        HStack(alignment: .top, spacing: Self.spacing) {
            ForEach(weekStarts, id: \.self) { weekStart in
                weekColumn(weekStart, scale: scale)
            }
        }
    }

    private func weekColumn(_ weekStart: Date, scale: IntensityScale) -> some View {
        VStack(spacing: Self.spacing) {
            ForEach(0 ..< 7, id: \.self) { weekday in
                cell(for: cellDate(weekStart: weekStart, weekday: weekday), scale: scale)
            }
        }
    }

    private func cell(for date: Date?, scale: IntensityScale) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color(for: date, scale: scale))
            .frame(width: Self.cellSize, height: Self.cellSize)
    }

    private var weekdayLabels: some View {
        VStack(spacing: Self.spacing) {
            ForEach(0 ..< 7, id: \.self) { weekday in
                Text(weekdayLabel(weekday))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 14, height: Self.cellSize)
            }
        }
    }
}

// MARK: - Legend

extension CalendarHeatmapView {
    private var legend: some View {
        HStack(spacing: 4) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(legendOpacities, id: \.self) { opacity in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(legendFill(opacity))
                    .frame(width: 10, height: 10)
            }
            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var legendOpacities: [Double] {
        [0.0, 0.25, 0.5, 0.75, 1.0]
    }

    private func legendFill(_ opacity: Double) -> Color {
        opacity == 0 ? emptyCellColor : rampColor(opacity)
    }
}

// MARK: - Data

extension CalendarHeatmapView {
    /// Summing on a duplicate date (nothing today's producer emits, but
    /// nothing this view's contract forbids) keeps the grid crash-free where
    /// `uniqueKeysWithValues` would trap.
    private var intensityScale: IntensityScale {
        IntensityScale(
            totalsByDay: Dictionary(
                dailyTotals.map { ($0.date, $0.duration) },
                uniquingKeysWith: +
            ),
            maxValue: dailyTotals.map(\.duration).max() ?? 0
        )
    }

    private var weekStarts: [Date] {
        let today = calendar.startOfDay(for: .now)
        guard let thisWeek = calendar.dateInterval(
            of: .weekOfYear, for: today
        )?.start else { return [] }
        return (0 ..< Self.weekCount)
            .reversed()
            .compactMap {
                calendar.date(
                    byAdding: .weekOfYear, value: -$0, to: thisWeek
                )
            }
    }

    private func cellDate(weekStart: Date, weekday: Int) -> Date? {
        calendar.date(byAdding: .day, value: weekday, to: weekStart)
    }

    private func color(for date: Date?, scale: IntensityScale) -> Color {
        let today = calendar.startOfDay(for: .now)
        guard let date, date <= today else {
            return Color.clear
        }
        let value = scale.totalsByDay[date] ?? 0
        guard scale.maxValue > 0, value > 0 else {
            return emptyCellColor
        }
        return rampColor(value / scale.maxValue)
    }

    /// A whisper of the tint instead of a gray grid, so empty days recede
    /// while staying just visible enough to read as the grid's floor.
    private var emptyCellColor: Color {
        tint.opacity(0.12)
    }

    /// A clean opacity ramp with a lifted floor, so even the lightest logged
    /// day separates clearly from empty and the steps read as distinct.
    private func rampColor(_ intensity: Double) -> Color {
        tint.opacity(0.32 + 0.68 * intensity)
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = (weekday + calendar.firstWeekday - 1) % 7
        guard weekday % 2 == 1 else { return "" }
        return symbols[index]
    }
}
