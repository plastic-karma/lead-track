import SwiftUI

/// Dashboard header: today's date on the left, compact daily/weekly goal
/// rings on the right. Rings only appear when at least one goal is active,
/// and rest-day metrics are already excluded by `GoalSummary`.
struct TodayHeaderView: View {
    let metrics: [Metric]

    var body: some View {
        let daily = GoalSummary.daily(for: metrics)
        let weekly = GoalSummary.weekly(for: metrics)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 16) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if daily.hasGoals {
                    CompactGoalRing(label: "Daily", summary: daily)
                }
                if weekly.hasGoals {
                    CompactGoalRing(label: "Weekly", summary: weekly)
                }
            }
            Text(intention)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }

    /// A warm one-line anchor under the date: lead with the best streak the
    /// user has going, otherwise a gentle invitation to begin.
    private var intention: String {
        let streak = bestStreak
        if streak >= 2 {
            return "\(streak) days of showing up."
        }
        return "A fresh day to begin."
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

/// A small segmented ring with its met/total count beside it — the collapsed
/// form of the old full-width goal progress section. One segment per goal,
/// filling with the accent as goals are met, with a checkmark once all are
/// done.
private struct CompactGoalRing: View {
    let label: String
    let summary: GoalSummary

    var body: some View {
        HStack(spacing: 6) {
            ring
            VStack(alignment: .leading, spacing: 0) {
                Text("\(summary.met)/\(summary.total)")
                    .font(.caption.bold())
                    .monospacedDigit()
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(label) goals: \(summary.met) of \(summary.total) met"
        )
    }

    private var ring: some View {
        ZStack {
            ForEach(0 ..< summary.total, id: \.self, content: segment)
            if summary.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 24, height: 24)
    }

    private func segment(_ index: Int) -> some View {
        let span = 1.0 / Double(summary.total)
        let gap = summary.total > 1 ? 0.06 : 0.0
        return Circle()
            .trim(
                from: Double(index) * span + gap / 2,
                to: Double(index + 1) * span - gap / 2
            )
            .stroke(
                index < summary.met ? Color.accentColor : Theme.inactive,
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .rotationEffect(.degrees(-90))
    }
}
