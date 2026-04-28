import Charts
import SwiftUI

struct DetailedStatisticsView: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType
    let unit: String?
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section { chart }
                Section("Activity") {
                    CalendarHeatmapView(dailyTotals: dailyTotals)
                }
                goalsSection
                Section("Metrics") { durationGrid }
                Section("Sessions") { sessionsGrid }
                Section("Streaks") { streakGrid }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(recentTotals) { daily in
                BarMark(
                    x: .value("Date", daily.date, unit: .day),
                    y: .value(
                        chartLabel,
                        ValueFormatter.chartValue(
                            daily.duration, type: measurementType
                        )
                    )
                )
                .foregroundStyle(.orange.gradient)
            }
            if let goal = dailyGoal {
                goalRule(goal)
            }
        }
        .chartYAxisLabel(chartLabel)
        .frame(height: 200)
    }

    private var chartLabel: String {
        ValueFormatter.chartLabel(
            type: measurementType, unit: unit
        )
    }

    private func goalRule(
        _ goal: TimeInterval
    ) -> some ChartContent {
        RuleMark(
            y: .value(
                "Goal",
                ValueFormatter.chartValue(
                    goal, type: measurementType
                )
            )
        )
        .foregroundStyle(.green)
        .lineStyle(StrokeStyle(dash: [5, 5]))
    }
}

// MARK: - Goals

extension DetailedStatisticsView {
    @ViewBuilder
    private var goalsSection: some View {
        if dailyGoal != nil || weeklyGoal != nil {
            Section("Goals") {
                goalsGrid
            }
        }
    }

    private var goalsGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                if let goal = dailyGoal {
                    GoalProgressView(
                        label: "Today",
                        current: SessionStatistics.todayTotal(
                            from: dailyTotals
                        ),
                        goal: goal,
                        measurementType: measurementType,
                        unit: unit
                    )
                }
                if let goal = weeklyGoal {
                    GoalProgressView(
                        label: "This Week",
                        current: SessionStatistics.currentWeekTotal(
                            from: dailyTotals
                        ),
                        goal: goal,
                        measurementType: measurementType,
                        unit: unit
                    )
                }
            }
        }
    }
}

// MARK: - Metrics

extension DetailedStatisticsView {
    private var durationGrid: some View {
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
                    SessionStatistics.overallAverage(
                        from: dailyTotals
                    )
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

    private var streakGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                streakItem(
                    "Current Streak",
                    SessionStatistics.currentStreak(
                        from: dailyTotals
                    )
                )
                streakItem(
                    "Longest Streak",
                    SessionStatistics.longestStreak(
                        from: dailyTotals
                    )
                )
            }
        }
    }

    private var sessionsGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                countItem(
                    "Total",
                    SessionStatistics.totalSessions(from: dailyTotals)
                )
                rateItem(
                    "Per Day",
                    SessionStatistics.averageSessionsPerDay(
                        from: dailyTotals
                    )
                )
            }
            GridRow {
                rateItem(
                    "5-Day / Day",
                    SessionStatistics.recentAverageSessionsPerDay(
                        days: 5, from: dailyTotals
                    )
                )
            }
            Divider()
            GridRow {
                statItem(
                    "Avg Length",
                    SessionStatistics.averageSessionLength(
                        from: dailyTotals
                    )
                )
                statItem(
                    "5-Day Avg Length",
                    SessionStatistics.recentAverageSessionLength(
                        days: 5, from: dailyTotals
                    )
                )
            }
        }
    }
}

// MARK: - Helpers

extension DetailedStatisticsView {
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
            Text(
                ValueFormatter.formatShort(
                    value, type: measurementType
                )
            )
            .font(.headline)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func streakItem(
        _ title: String,
        _ days: Int
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(days)d")
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func countItem(
        _ title: String,
        _ count: Int
    ) -> some View {
        valueItem(title, "\(count)")
    }

    private func rateItem(
        _ title: String,
        _ rate: Double
    ) -> some View {
        valueItem(title, String(format: "%.1f", rate))
    }

    private func valueItem(
        _ title: String,
        _ text: String
    ) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.headline)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }
}
