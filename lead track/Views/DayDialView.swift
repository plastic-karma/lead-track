import SwiftUI

/// The Today screen's header instrument: a segmented day dial — one arc per
/// active daily goal, each wearing its metric's color — beside the date and
/// a warm streak line. Replaces the single accent ring so the header shows
/// *which* of the day's goals are met, not just how many; rest-day metrics
/// are excluded by the same rule as `GoalSummary`.
struct DayDialView: View {
    let metrics: [Metric]

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            if !arcs.isEmpty {
                SegmentedGoalDial(arcs: arcs)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title2.weight(.bold))
                    .tracking(-0.2)
                streakLine
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }
}

// MARK: - Segments

extension DayDialView {
    /// Metrics with an active daily target today — one dial segment each.
    private var goalMetrics: [Metric] {
        metrics.filter {
            GoalSummary.hasDailyTarget($0) && $0.isGoalDay(on: .now)
        }
    }

    private var arcs: [GoalDialArc] {
        goalMetrics.enumerated().map { index, metric in
            GoalDialArc(
                id: index,
                tint: metric.displayColor,
                fraction: TodayGrouping.completionFraction(metric)
            )
        }
    }
}

// MARK: - Streak

extension DayDialView {
    /// A warm one-line anchor under the date: lead with the best streak the
    /// user has going — noting when today already held — otherwise a gentle
    /// invitation to begin.
    @ViewBuilder
    private var streakLine: some View {
        let streak = bestStreak
        if streak >= 2 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text(streakText(streak))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("A fresh day to begin.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func streakText(_ streak: Int) -> String {
        let base = "\(streak) days of showing up"
        let complete = GoalSummary.daily(for: metrics).isComplete
        return complete ? base + " — today held" : base
    }

    private var bestStreak: Int {
        metrics.map { metric in
            SessionStatistics.currentStreak(
                from: SessionStatistics.dailyTotals(from: metric.sessions),
                excludedWeekdays: metric.excludedWeekdaySet
            )
        }.max() ?? 0
    }
}
