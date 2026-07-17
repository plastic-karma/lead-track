import SwiftUI

/// The Today screen's header instrument: chevrons for browsing days around a
/// relative title (the same controls the Week tab's header strip wears), then
/// a segmented day dial — one arc per active daily goal, each wearing its
/// metric's color — beside the browsed day's date. Today closes the line with
/// a warm streak; an earlier day closes with how its goals held instead.
/// Rest-day metrics are excluded by the same rule as `GoalSummary`.
struct DayDialView: View {
    let metrics: [Metric]
    /// How many days back the header (and the whole Today screen) is
    /// browsing — 0 is today, owned by `MetricListView` so the cluster
    /// sections read the same day.
    @Binding var daysBack: Int

    var body: some View {
        VStack(spacing: 12) {
            navigationRow
            heroRow
        }
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    /// The instant every reading below describes — today when the chevrons
    /// rest.
    private var day: Date {
        TodayGrouping.day(back: daysBack)
    }

    private var isToday: Bool {
        daysBack == 0
    }
}

// MARK: - Day navigation

extension DayDialView {
    private var navigationRow: some View {
        HStack(spacing: 10) {
            chevron("chevron.left", label: "Earlier day") {
                daysBack += 1
            }
            Spacer()
            Text(dayTitle)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Spacer()
            chevron("chevron.right", label: "Later day") {
                daysBack -= 1
            }
            .disabled(isToday)
            .opacity(isToday ? 0.4 : 1)
        }
    }

    private func chevron(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Theme.chipFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var dayTitle: String {
        switch daysBack {
        case 0: "Today"
        case 1: "Yesterday"
        default: "\(daysBack) Days Ago"
        }
    }
}

// MARK: - Hero row

extension DayDialView {
    private var heroRow: some View {
        HStack(alignment: .center, spacing: 18) {
            if !arcs.isEmpty {
                SegmentedGoalDial(arcs: arcs)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(day, format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(.title2.weight(.bold))
                    .tracking(-0.2)
                subtitleLine
            }
        }
    }

    /// Today keeps its streak line; a browsed earlier day reads how its
    /// goals closed instead.
    @ViewBuilder
    private var subtitleLine: some View {
        if isToday {
            streakLine
        } else {
            pastDayLine
        }
    }
}

// MARK: - Segments

extension DayDialView {
    /// Metrics with an active daily target on the browsed day — one dial
    /// segment each.
    private var goalMetrics: [Metric] {
        metrics.filter {
            GoalSummary.hasDailyTarget($0) && $0.isGoalDay(on: day)
        }
    }

    private var arcs: [GoalDialArc] {
        goalMetrics.enumerated().map { index, metric in
            GoalDialArc(
                id: index,
                tint: metric.displayColor,
                fraction: TodayGrouping.completionFraction(metric, now: day)
            )
        }
    }
}

// MARK: - Past days

extension DayDialView {
    /// The browsed day's quiet reading where today's streak line stands: how
    /// that day's goals closed. Days without an active goal stay bare — the
    /// date alone carries them.
    @ViewBuilder
    private var pastDayLine: some View {
        let summary = GoalSummary.daily(for: metrics, now: day)
        if summary.hasGoals {
            Text(summary.isComplete ? "Every goal held." : "\(summary.met) of \(summary.total) held")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
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
