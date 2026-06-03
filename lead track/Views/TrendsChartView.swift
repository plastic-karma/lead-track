import Charts
import SwiftUI

/// A trends chart of daily or weekly totals with a goal reference line and,
/// in daily mode, a 7-day rolling-average overlay.
struct TrendsChartView: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType
    let unit: String?
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    @State private var range: TrendsRange = .twoWeeks

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Range", selection: $range) {
                ForEach(TrendsRange.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            chart
            legend
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chart

extension TrendsChartView {
    private var chart: some View {
        Chart {
            barMarks
            averageMarks
            goalMark
        }
        .chartYAxisLabel(chartLabel)
        .frame(height: 200)
    }

    @ChartContentBuilder
    private var barMarks: some ChartContent {
        ForEach(bars) { point in
            BarMark(
                x: .value("Date", point.date, unit: barUnit),
                y: .value(chartLabel, plot(point.duration))
            )
            .foregroundStyle(.orange.gradient)
        }
    }

    @ChartContentBuilder
    private var averageMarks: some ChartContent {
        if !range.isWeekly {
            ForEach(average) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value(chartLabel, plot(point.duration))
                )
                .foregroundStyle(.blue)
                .interpolationMethod(.catmullRom)
            }
        }
    }

    @ChartContentBuilder
    private var goalMark: some ChartContent {
        if let goal = activeGoal {
            RuleMark(y: .value("Goal", plot(goal)))
                .foregroundStyle(.green)
                .lineStyle(StrokeStyle(dash: [5, 5]))
        }
    }
}

// MARK: - Legend

extension TrendsChartView {
    private var legend: some View {
        HStack(spacing: 12) {
            legendItem(color: .orange, label: barLabel)
            if !range.isWeekly {
                legendItem(color: .blue, label: "7-day avg")
            }
            if activeGoal != nil {
                legendItem(color: .green, label: "Goal")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }

    private var barLabel: String {
        range.isWeekly ? "Weekly total" : "Daily total"
    }
}

// MARK: - Data

extension TrendsChartView {
    private var bars: [DailyTotal] {
        range.isWeekly
            ? SessionStatistics.weeklyTotals(from: dailyTotals, since: cutoff)
            : dailyTotals.filter { $0.date >= cutoff }
    }

    private var average: [DailyTotal] {
        SessionStatistics.movingAverage(days: 7, from: dailyTotals, since: cutoff)
    }

    private var cutoff: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: -(range.days - 1), to: start) ?? start
    }

    private var activeGoal: TimeInterval? {
        range.isWeekly ? weeklyGoal : dailyGoal
    }

    private var barUnit: Calendar.Component {
        range.isWeekly ? .weekOfYear : .day
    }

    private func plot(_ value: TimeInterval) -> Double {
        ValueFormatter.chartValue(value, type: measurementType)
    }

    private var chartLabel: String {
        ValueFormatter.chartLabel(type: measurementType, unit: unit)
    }
}

// MARK: - Range

enum TrendsRange: String, CaseIterable, Identifiable {
    case twoWeeks
    case eightWeeks
    case sixMonths

    var id: String {
        rawValue
    }

    var days: Int {
        switch self {
        case .twoWeeks: 14
        case .eightWeeks: 56
        case .sixMonths: 182
        }
    }

    var isWeekly: Bool {
        self != .twoWeeks
    }

    var label: String {
        switch self {
        case .twoWeeks: "2 Weeks"
        case .eightWeeks: "8 Weeks"
        case .sixMonths: "6 Months"
        }
    }
}
