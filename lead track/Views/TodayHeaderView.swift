import SwiftUI

/// The Today screen's header: the day and a warm streak line on the left, a
/// single daily-goal progress ring on the right. The ring only appears once at
/// least one metric carries a daily goal for today; rest-day metrics are
/// already excluded by `GoalSummary`.
struct TodayHeaderView: View {
    let metrics: [Metric]

    var body: some View {
        let daily = GoalSummary.daily(for: metrics)
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                streakLine
            }
            Spacer()
            if daily.hasGoals {
                DailyProgressRing(summary: daily)
            }
        }
        .padding(.vertical, 4)
    }

    /// A warm one-line anchor under the date: lead with the best streak the
    /// user has going, otherwise a gentle invitation to begin.
    @ViewBuilder
    private var streakLine: some View {
        let streak = bestStreak
        if streak >= 2 {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
                Text("\(streak) days of showing up")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        } else {
            Text("A fresh day to begin.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
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

/// A single continuous progress ring with its done/total count beside it — how
/// much of today's goals are met at a glance. The arc fills with the accent and
/// shows a checkmark once every goal is done.
private struct DailyProgressRing: View {
    let summary: GoalSummary

    private var fraction: Double {
        guard summary.total > 0 else { return 0 }
        return Double(summary.met) / Double(summary.total)
    }

    var body: some View {
        HStack(spacing: 10) {
            ring
            VStack(alignment: .leading, spacing: 0) {
                Text("\(summary.met) of \(summary.total)")
                    .font(.headline)
                    .monospacedDigit()
                Text("done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(summary.met) of \(summary.total) daily goals done"
        )
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(Theme.inactive, lineWidth: 5)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            if summary.isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.tint)
            }
        }
        .frame(width: 44, height: 44)
        .animation(.snappy, value: fraction)
    }
}
