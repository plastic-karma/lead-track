import Charts
import SwiftUI

struct DetailedStatisticsView: View {
    let dailyTotals: [DailyTotal]
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section { chart }
                goalsSection
                Section("Metrics") { durationGrid }
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
                    y: .value("Minutes", daily.duration / 60)
                )
                .foregroundStyle(.orange.gradient)
            }
            if let goal = dailyGoal {
                goalRule(goal)
            }
        }
        .chartYAxisLabel("min")
        .frame(height: 200)
    }

    private func goalRule(
        _ goal: TimeInterval
    ) -> some ChartContent {
        RuleMark(y: .value("Goal", goal / 60))
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
                        goal: goal
                    )
                }
                if let goal = weeklyGoal {
                    GoalProgressView(
                        label: "This Week",
                        current: SessionStatistics.currentWeekTotal(
                            from: dailyTotals
                        ),
                        goal: goal
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
            Text(DurationFormatter.format(value))
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
}
