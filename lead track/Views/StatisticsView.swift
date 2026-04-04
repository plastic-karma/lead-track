import Charts
import SwiftUI

struct StatisticsView: View {
    let sessions: [Session]

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Statistics") {
                statsGrid
                chart
            }
        }
    }

    private var statsGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                statItem(
                    "Today",
                    SessionStatistics.todayTotal(from: dailyTotals)
                )
                statItem(
                    "Total",
                    SessionStatistics.overallTotal(from: dailyTotals)
                )
            }
            Divider()
            GridRow {
                statItem(
                    "5-Day Avg",
                    SessionStatistics.recentAverage(
                        days: 5,
                        from: dailyTotals
                    )
                )
                statItem(
                    "Overall Avg",
                    SessionStatistics.overallAverage(from: dailyTotals)
                )
            }
            GridRow {
                statItem(
                    "Best Day",
                    SessionStatistics.maxDaily(from: dailyTotals)
                )
            }
        }
    }

    private var chart: some View {
        Chart(recentTotals) { daily in
            BarMark(
                x: .value("Date", daily.date, unit: .day),
                y: .value("Minutes", daily.duration / 60)
            )
            .foregroundStyle(.orange.gradient)
        }
        .chartYAxisLabel("min")
        .frame(height: 150)
    }
}

// MARK: - Helpers

extension StatisticsView {
    private var recentTotals: [DailyTotal] {
        guard let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -13,
            to: Calendar.current.startOfDay(for: .now)
        ) else { return [] }
        return dailyTotals.filter { $0.date >= cutoff }
    }

    private func statItem(
        _ title: String,
        _ value: TimeInterval
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(DurationFormatter.format(value))
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
