import SwiftUI

struct StatisticsView: View {
    let sessions: [Session]
    let measurementType: MeasurementType
    let unit: String?
    let dailyGoal: TimeInterval?
    let weeklyGoal: TimeInterval?
    @Binding var showingDetailedStats: Bool

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Statistics") {
                statsContent
                Button {
                    showingDetailedStats = true
                } label: {
                    Label(
                        "All Statistics",
                        systemImage: "chart.bar.xaxis"
                    )
                }
            }
        }
    }

    private var statsContent: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                todayItem
                weeklyOrTotalItem
                streakItem(
                    "Streak",
                    SessionStatistics.currentStreak(
                        from: dailyTotals
                    )
                )
            }
        }
    }
}

// MARK: - Items

extension StatisticsView {
    @ViewBuilder
    private var todayItem: some View {
        let today = SessionStatistics.todayTotal(from: dailyTotals)
        if let goal = dailyGoal {
            GoalProgressView(
                label: "Today",
                current: today,
                goal: goal,
                measurementType: measurementType,
                unit: unit
            )
        } else {
            statItem("Today", today)
        }
    }

    @ViewBuilder
    private var weeklyOrTotalItem: some View {
        if let goal = weeklyGoal {
            GoalProgressView(
                label: "Week",
                current: SessionStatistics.currentWeekTotal(
                    from: dailyTotals
                ),
                goal: goal,
                measurementType: measurementType,
                unit: unit
            )
        } else {
            statItem(
                "Total",
                SessionStatistics.overallTotal(from: dailyTotals)
            )
        }
    }
}

// MARK: - Helpers

extension StatisticsView {
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
}
