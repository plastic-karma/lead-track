import SwiftData
import SwiftUI

/// The metric detail's instrument: today's ring nested inside the week's.
/// The inner ring wears the metric's color solid and grades the daily goal;
/// the outer ring wears it soft and grades the weekly goal, with the pace
/// expectation as a notch — the gap between fill and notch is the "behind".
/// Exact numbers read from the center and the coach line underneath, not the
/// rings. Metrics with one goal get a single full-size ring; metrics with
/// none keep the plain hero numeral; binary habits show today's check.
struct MetricRingCard: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let activeSession: Session?
    let todayTotal: TimeInterval
    let weekTotal: TimeInterval
    @State private var isSyncingHealth = false

    var body: some View {
        VStack(spacing: 14) {
            if metric.measurementType == .binary || hasRings {
                ringCluster
            } else {
                bareValue
            }
            if weeklyFraction != nil {
                legend
            }
            if let coachLine {
                coachRow(coachLine)
            }
            if metric.isHealthLinked {
                healthProvenance
            }
        }
        .padding(.vertical, 6)
        .cardSurface(alignment: .center)
    }

    private var tint: Color {
        metric.displayColor
    }
}

// MARK: - Fractions

extension MetricRingCard {
    private var hasRings: Bool {
        dailyFraction != nil || weeklyFraction != nil
    }

    /// Daily-goal progress, shown even on rest days (the caption reframes it);
    /// binary habits grade their show-up check instead.
    private var dailyFraction: Double? {
        if metric.measurementType == .binary {
            return isDoneToday ? 1 : 0
        }
        guard let goal = metric.dailyGoal, goal > 0 else { return nil }
        return min(todayTotal / goal, 1)
    }

    private var weeklyFraction: Double? {
        guard metric.measurementType.tracksQuantity,
              let goal = metric.weeklyGoal, goal > 0
        else { return nil }
        return min(weekTotal / goal, 1)
    }

    /// Where the week "should" be by now — the notch on the outer ring.
    private var notchFraction: Double? {
        guard let pace = weekPace, pace.goal > 0 else { return nil }
        return min(pace.expected / pace.goal, 1)
    }

    private var weekPace: GoalPace? {
        guard metric.measurementType.tracksQuantity else { return nil }
        return GoalPace.weekly(
            actual: weekTotal,
            goal: metric.weeklyGoal ?? 0,
            excludedWeekdays: metric.excludedWeekdaySet
        )
    }

    private var isDoneToday: Bool {
        todayTotal > 0
    }

    private var isRestDay: Bool {
        !metric.isGoalDay(on: .now)
    }
}

// MARK: - Ring Cluster

extension MetricRingCard {
    private var ringCluster: some View {
        MetricRingCluster(
            today: dailyFraction,
            week: weeklyFraction,
            notch: notchFraction,
            tint: tint,
            center: center
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

// MARK: - Center

extension MetricRingCard {
    private var center: some View {
        VStack(spacing: 1) {
            centerValue
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: centerWidth)
            Text(centerCaption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var centerValue: some View {
        if metric.measurementType == .binary {
            Image(systemName: isDoneToday ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 30, weight: .semibold))
        } else {
            liveValueText
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: activeSession?.countsDown ?? false))
        }
    }

    @ViewBuilder
    private var liveValueText: some View {
        if let session = activeSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(backdatedBy: todayTotal)
            )
        } else {
            Text(ValueFormatter.formatShort(todayTotal, type: metric.measurementType))
        }
    }

    private var centerWidth: CGFloat {
        weeklyFraction == nil ? 110 : 88
    }

    private var centerCaption: String {
        if metric.measurementType == .binary {
            return isDoneToday ? "done today" : "not done yet"
        }
        if isRestDay { return "rest day" }
        guard let goal = metric.dailyGoal, goal > 0 else { return "today" }
        return "of \(goalText(goal))"
    }

    private func goalText(_ goal: Double) -> String {
        metric.measurementType == .duration
            ? DurationFormatter.compact(goal)
            : String(Int(goal))
    }

    private var accessibilitySummary: String {
        var parts = ["Today \(ValueFormatter.formatShort(todayTotal, type: metric.measurementType))"]
        if let goal = metric.dailyGoal, goal > 0 {
            parts.append("of \(goalText(goal))")
        }
        if let goal = metric.weeklyGoal, goal > 0 {
            parts
                .append(
                    "week \(ValueFormatter.formatShort(weekTotal, type: metric.measurementType)) of \(goalText(goal))"
                )
        }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Bare Value

extension MetricRingCard {
    /// The goalless fallback: the plain hero numeral, no instrument to grade.
    private var bareValue: some View {
        VStack(spacing: 6) {
            liveValueText
                .numeralStyle(.hero)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: activeSession?.countsDown ?? false))
            Text(unitCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var unitCaption: String {
        guard metric.measurementType == .count,
              let unit = metric.unit, !unit.isEmpty
        else { return "today" }
        return "\(unit) today"
    }
}

// MARK: - Legend & Coach

extension MetricRingCard {
    /// One dot per visible ring, so a week-only cluster never advertises a
    /// today ring it doesn't draw.
    private var legend: some View {
        HStack(spacing: 18) {
            if dailyFraction != nil {
                legendDot(tint, label: "today")
            }
            legendDot(tint.opacity(0.45), label: "week")
        }
        .accessibilityHidden(true)
    }

    private func legendDot(_ color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var coachLine: String? {
        guard let pace = weekPace else { return nil }
        return GoalCoach(
            pace: pace,
            measurementType: metric.measurementType,
            excludedWeekdays: metric.excludedWeekdaySet
        ).line
    }

    private func coachRow(_ line: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: coachSymbol)
                .font(.footnote)
            Text(line)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var coachSymbol: String {
        switch weekPace?.status {
        case .achieved: "checkmark.seal.fill"
        case .ahead: "gauge.with.dots.needle.67percent"
        case .behind: "gauge.with.dots.needle.33percent"
        default: "gauge.with.dots.needle.50percent"
        }
    }
}

// MARK: - Health Provenance

extension MetricRingCard {
    /// Health metrics record themselves, so instead of the record dock the
    /// card carries where the numbers come from and a manual sync.
    private var healthProvenance: some View {
        HStack(spacing: 16) {
            Label("From Apple Health", systemImage: "heart.fill")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Sync Now", action: syncNow)
                .font(.footnote.weight(.medium))
                .disabled(isSyncingHealth)
        }
    }

    private func syncNow() {
        guard let id = metric.stableID else { return }
        isSyncingHealth = true
        let container = modelContext.container
        Task {
            await HealthMetricSyncService.shared.connect(
                metricID: id, container: container
            )
            isSyncingHealth = false
        }
    }
}
