import SwiftUI

/// The statistics card on the detail screens. Today's value and daily-goal
/// progress live in the hero directly above, so this card sticks to the
/// longer arcs: the current week when a weekly goal is set, the lifetime
/// total, and the streak.
struct StatisticsView: View {
    let sessions: [Session]
    let measurementType: MeasurementType
    let unit: String?
    let weeklyGoal: TimeInterval?
    let excludedWeekdays: [Int]
    @Binding var showingDetailedStats: Bool
    var tint: Color = .accentColor

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Statistics") {
                statsContent
                paceBanner
                Button {
                    showingDetailedStats = true
                } label: {
                    Label(
                        "All Statistics",
                        systemImage: "chart.bar.xaxis"
                    )
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var paceBanner: some View {
        if let pace = weekPace {
            GoalPaceView(
                pace: pace,
                measurementType: measurementType,
                unit: unit,
                tint: tint
            )
        }
    }

    private var weekPace: GoalPace? {
        GoalPace.forWeek(
            dailyTotals: dailyTotals,
            weeklyGoal: weeklyGoal,
            excludedWeekdays: excludedWeekdays
        )
    }

    private var statsContent: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                if let goal = weeklyGoal {
                    weekItem(goal)
                }
                statItem(
                    "Total",
                    SessionStatistics.overallTotal(from: dailyTotals)
                )
                streakItem(
                    "Streak",
                    SessionStatistics.currentStreak(
                        from: dailyTotals,
                        excludedWeekdays: Set(excludedWeekdays)
                    )
                )
            }
        }
    }
}

// MARK: - Items

extension StatisticsView {
    private func weekItem(_ goal: TimeInterval) -> some View {
        GoalProgressView(
            label: "Week",
            current: SessionStatistics.currentWeekTotal(
                from: dailyTotals
            ),
            goal: goal,
            measurementType: measurementType,
            unit: unit,
            tint: tint
        )
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
            .numeralStyle(.stat)
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
                .numeralStyle(.stat)
        }
        .frame(maxWidth: .infinity)
    }
}
