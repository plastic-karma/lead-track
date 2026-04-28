import SwiftUI

struct CalendarHeatmapView: View {
    let dailyTotals: [DailyTotal]

    private static let weekCount = 16
    private static let cellSize: CGFloat = 14
    private static let spacing: CGFloat = 3

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 6) {
                weekdayLabels
                grid
            }
            legend
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Grid

extension CalendarHeatmapView {
    private var grid: some View {
        HStack(alignment: .top, spacing: Self.spacing) {
            ForEach(weekStarts, id: \.self) { weekStart in
                weekColumn(weekStart)
            }
        }
    }

    private func weekColumn(_ weekStart: Date) -> some View {
        VStack(spacing: Self.spacing) {
            ForEach(0 ..< 7, id: \.self) { weekday in
                cell(for: cellDate(weekStart: weekStart, weekday: weekday))
            }
        }
    }

    private func cell(for date: Date?) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(color(for: date))
            .frame(width: Self.cellSize, height: Self.cellSize)
    }

    private var weekdayLabels: some View {
        VStack(spacing: Self.spacing) {
            ForEach(0 ..< 7, id: \.self) { weekday in
                Text(weekdayLabel(weekday))
                    .font(.system(size: 9))
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
                RoundedRectangle(cornerRadius: 2)
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
        opacity == 0
            ? Color.gray.opacity(0.15)
            : Color.orange.opacity(0.25 + 0.75 * opacity)
    }
}

// MARK: - Data

extension CalendarHeatmapView {
    private var totalsByDay: [Date: TimeInterval] {
        Dictionary(
            uniqueKeysWithValues: dailyTotals.map { ($0.date, $0.duration) }
        )
    }

    private var maxValue: TimeInterval {
        dailyTotals.map(\.duration).max() ?? 0
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

    private func color(for date: Date?) -> Color {
        let today = calendar.startOfDay(for: .now)
        guard let date, date <= today else {
            return Color.clear
        }
        let value = totalsByDay[date] ?? 0
        guard maxValue > 0, value > 0 else {
            return Color.gray.opacity(0.15)
        }
        let intensity = value / maxValue
        return Color.orange.opacity(0.25 + 0.75 * intensity)
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = calendar.veryShortWeekdaySymbols
        let index = (weekday + calendar.firstWeekday - 1) % 7
        guard weekday % 2 == 1 else { return "" }
        return symbols[index]
    }
}
