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
        // One aggregation pass per render, shared by every stat below.
        let totals = dailyTotals
        if !totals.isEmpty {
            Section("Statistics") {
                statsContent(totals)
                paceBanner(totals)
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
    private func paceBanner(_ totals: [DailyTotal]) -> some View {
        if let pace = weekPace(totals) {
            GoalPaceView(
                pace: pace,
                measurementType: measurementType,
                unit: unit,
                tint: tint
            )
        }
    }

    private func weekPace(_ totals: [DailyTotal]) -> GoalPace? {
        GoalPace.forWeek(
            dailyTotals: totals,
            weeklyGoal: weeklyGoal,
            excludedWeekdays: excludedWeekdays
        )
    }

    private func statsContent(_ totals: [DailyTotal]) -> some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                if let goal = weeklyGoal {
                    weekItem(goal, totals: totals)
                }
                statItem(
                    "Total",
                    SessionStatistics.overallTotal(from: totals)
                )
                StatGridItem(
                    title: "Streak",
                    streak: SessionStatistics.currentStreak(
                        from: totals,
                        excludedWeekdays: Set(excludedWeekdays)
                    )
                )
            }
        }
    }
}

// MARK: - Items

extension StatisticsView {
    private func weekItem(_ goal: TimeInterval, totals: [DailyTotal]) -> some View {
        GoalProgressView(
            label: "Week",
            current: SessionStatistics.currentWeekTotal(
                from: totals
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
        StatGridItem(
            title: title,
            text: ValueFormatter.formatShort(value, type: measurementType)
        )
    }
}

// MARK: - Grid Cell

/// One cell of the statistics grids — a caption title over the stat numeral —
/// shared by this summary card and the detailed-statistics sheet so the two
/// surfaces can never drift apart.
struct StatGridItem: View {
    let title: String
    let text: String

    init(title: String, text: String) {
        self.title = title
        self.text = text
    }

    init(title: String, streak days: Int) {
        self.init(title: title, text: "\(days)d")
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .numeralStyle(.stat)
        }
        .frame(maxWidth: .infinity)
    }
}
