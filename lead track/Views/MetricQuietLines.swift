import SwiftUI

/// The long arcs as one quiet centered line — all-time, streak, best day —
/// with the standing notes (default project, past season) underneath. The
/// numbers the rings above don't carry live here, in caption type.
struct MetricQuietLines: View {
    let metric: Metric
    let dailyTotals: [DailyTotal]

    var body: some View {
        VStack(spacing: 6) {
            if !statsLine.isEmpty {
                Text(statsLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let project = metric.defaultProject {
                quietNote("Logging to \(project.name)", systemImage: "star.fill")
            }
            // The quiet "past season" tag: a fact, not a judgment — the goal
            // keeps working in full (see `GoalSeason`).
            if case .pastSeason = GoalSeason.phase(of: metric) {
                quietNote("Goal past its season — review it under Goals", systemImage: "leaf")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}

// MARK: - Lines

extension MetricQuietLines {
    private var statsLine: String {
        var parts: [String] = []
        let allTime = SessionStatistics.overallTotal(from: dailyTotals)
        if allTime > 0 {
            parts.append("\(allTimeText(allTime)) all-time")
        }
        let streak = SessionStatistics.currentStreak(
            from: dailyTotals, excludedWeekdays: metric.excludedWeekdaySet
        )
        if streak > 0 {
            parts.append("\(streak)-day streak")
        }
        let best = SessionStatistics.maxDaily(from: dailyTotals)
        if best > 0, metric.measurementType.tracksQuantity {
            parts.append("best day \(ValueFormatter.formatShort(best, type: metric.measurementType))")
        }
        return parts.joined(separator: " · ")
    }

    /// Binary all-time totals read as done days ("42 days"), everything else
    /// in the metric's own unit.
    private func allTimeText(_ total: Double) -> String {
        metric.measurementType == .binary
            ? ValueFormatter.format(total, type: .binary)
            : ValueFormatter.formatShort(total, type: metric.measurementType)
    }

    private func quietNote(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
