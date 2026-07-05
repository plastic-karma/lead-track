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
            if !segments.isEmpty {
                DaySegmentDial(segments: segments)
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

    private var segments: [DialSegment] {
        goalMetrics.enumerated().map { index, metric in
            DialSegment(
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

// MARK: - Dial

/// One goal's share of the dial.
private struct DialSegment: Identifiable {
    let id: Int
    let tint: Color
    /// Progress within the segment, 0–1; 1 fills it whole.
    let fraction: Double
}

/// A 92 pt dial divided into equal arc segments with small gaps, starting at
/// 12 o'clock. Each segment fills with its metric's color as the goal
/// progresses; once every goal is met the whole dial settles into the accent
/// and a checkmark replaces the count — the day held.
private struct DaySegmentDial: View {
    let segments: [DialSegment]

    private static let gapDegrees = 12.0

    private var isComplete: Bool {
        segments.allSatisfy { $0.fraction >= 1 }
    }

    private var metCount: Int {
        segments.count { $0.fraction >= 1 }
    }

    var body: some View {
        ZStack {
            ForEach(segments) { segment in
                arc(at: segment.id, fraction: 1, color: Theme.inactive)
                arc(
                    at: segment.id,
                    fraction: segment.fraction,
                    color: isComplete ? .accentColor : segment.tint
                )
            }
            center
        }
        .frame(width: 92, height: 92)
        .animation(.snappy, value: segments.map(\.fraction))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(metCount) of \(segments.count) daily goals done")
    }

    /// One arc: `fraction` of the segment's sweep, drawn clockwise from the
    /// segment's start. The full circle is shared equally with a small gap
    /// between neighbors, the first gap centered on 12 o'clock.
    private func arc(at index: Int, fraction: Double, color: Color) -> some View {
        let share = 360.0 / Double(segments.count)
        let sweep = max(share - Self.gapDegrees, 4)
        let start = -90 + Self.gapDegrees / 2 + Double(index) * share
        return Circle()
            .trim(from: 0, to: sweep * min(max(fraction, 0), 1) / 360)
            .stroke(color, style: StrokeStyle(lineWidth: 7, lineCap: .round))
            .rotationEffect(.degrees(start))
            .padding(6)
    }

    @ViewBuilder
    private var center: some View {
        if isComplete {
            VStack(spacing: 2) {
                Image(systemName: "checkmark")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Text("done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(spacing: 0) {
                Text("\(metCount)/\(segments.count)")
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("done")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
