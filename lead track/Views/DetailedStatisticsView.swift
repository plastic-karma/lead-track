import SwiftUI

struct DetailedStatisticsView: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType
    let unit: String?
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    let excludedWeekdays: [Int]
    var tint: Color = .accentColor
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TrendsChartView(
                        dailyTotals: dailyTotals, measurementType: measurementType, unit: unit,
                        dailyGoal: dailyGoal, weeklyGoal: weeklyGoal, tint: tint
                    )
                }
                DetailedGoalsSection(
                    dailyTotals: dailyTotals, measurementType: measurementType, unit: unit,
                    dailyGoal: dailyGoal, weeklyGoal: weeklyGoal, excludedWeekdays: excludedWeekdays, tint: tint
                )
                Section("Metrics") {
                    DetailedDurationGrid(dailyTotals: dailyTotals, measurementType: measurementType)
                }
                Section("Sessions") {
                    DetailedSessionsGrid(dailyTotals: dailyTotals, measurementType: measurementType)
                }
                Section("Streaks") {
                    DetailedStreakGrid(dailyTotals: dailyTotals, excludedWeekdays: excludedWeekdays)
                }
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
}

// MARK: - Goals

private struct DetailedGoalsSection: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType
    let unit: String?
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    let excludedWeekdays: [Int]
    let tint: Color

    var body: some View {
        if dailyGoal != nil || weeklyGoal != nil {
            Section("Goals") {
                goalsGrid
                paceBanner
            }
        }
    }

    @ViewBuilder
    private var paceBanner: some View {
        if let pace = weekPace {
            GoalPaceView(pace: pace, measurementType: measurementType, unit: unit)
        }
    }

    private var weekPace: GoalPace? {
        GoalPace.forWeek(
            dailyTotals: dailyTotals,
            weeklyGoal: weeklyGoal,
            excludedWeekdays: excludedWeekdays
        )
    }

    private var goalsGrid: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                if let goal = dailyGoal {
                    dailyGoalItem(goal)
                }
                if let goal = weeklyGoal {
                    weeklyGoalItem(goal)
                }
            }
        }
    }

    private func dailyGoalItem(_ goal: TimeInterval) -> some View {
        DailyGoalItem(
            label: "Today",
            today: SessionStatistics.todayTotal(from: dailyTotals),
            goal: goal,
            excludedWeekdays: excludedWeekdays,
            measurementType: measurementType,
            tint: tint
        )
    }

    private func weeklyGoalItem(_ goal: TimeInterval) -> some View {
        GoalProgressView(
            label: "This Week",
            current: SessionStatistics.currentWeekTotal(from: dailyTotals),
            goal: goal,
            measurementType: measurementType,
            tint: tint
        )
    }
}

// MARK: - Metrics

private struct DetailedDurationGrid: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType

    var body: some View {
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

    private func statItem(
        _ title: String,
        _ value: TimeInterval
    ) -> some View {
        StatGridItem(
            title: title,
            text: ValueFormatter.formatShort(value, type: measurementType)
        )
    }
}

private struct DetailedStreakGrid: View {
    let dailyTotals: [DailyTotal]
    let excludedWeekdays: [Int]

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                StatGridItem(
                    title: "Current Streak",
                    streak: SessionStatistics.currentStreak(
                        from: dailyTotals,
                        excludedWeekdays: Set(excludedWeekdays)
                    )
                )
                StatGridItem(
                    title: "Longest Streak",
                    streak: SessionStatistics.longestStreak(
                        from: dailyTotals,
                        excludedWeekdays: Set(excludedWeekdays)
                    )
                )
            }
        }
    }
}

private struct DetailedSessionsGrid: View {
    let dailyTotals: [DailyTotal]
    let measurementType: MeasurementType

    var body: some View {
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

    private func statItem(
        _ title: String,
        _ value: TimeInterval
    ) -> some View {
        StatGridItem(
            title: title,
            text: ValueFormatter.formatShort(value, type: measurementType)
        )
    }

    private func countItem(
        _ title: String,
        _ count: Int
    ) -> some View {
        StatGridItem(title: title, text: count.formatted())
    }

    private func rateItem(
        _ title: String,
        _ rate: Double
    ) -> some View {
        // Locale-aware (f-47) through the shared stat tile (dedup).
        StatGridItem(title: title, text: rate.formatted(.number.precision(.fractionLength(1))))
    }
}
