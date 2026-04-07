import SwiftUI

struct StatisticsView: View {
    let sessions: [Session]
    @Binding var showingDetailedStats: Bool

    private var dailyTotals: [DailyTotal] {
        SessionStatistics.dailyTotals(from: sessions)
    }

    var body: some View {
        if !dailyTotals.isEmpty {
            Section("Statistics") {
                Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                    GridRow {
                        statItem(
                            "Today",
                            SessionStatistics.todayTotal(from: dailyTotals)
                        )
                        statItem(
                            "Total",
                            SessionStatistics.overallTotal(
                                from: dailyTotals
                            )
                        )
                        streakItem(
                            "Streak",
                            SessionStatistics.currentStreak(
                                from: dailyTotals
                            )
                        )
                    }
                }
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
