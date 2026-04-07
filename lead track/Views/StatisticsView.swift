import SwiftUI

struct StatisticsView: View {
    let sessions: [Session]
    @State private var showingDetailedStats = false

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
            .sheet(isPresented: $showingDetailedStats) {
                DetailedStatisticsView(dailyTotals: dailyTotals)
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
}
