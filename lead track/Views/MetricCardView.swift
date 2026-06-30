import SwiftData
import SwiftUI

/// One dashboard card per metric: identity, today's value with a seven-day
/// sparkline, streak, optional goal progress, and the primary action
/// (start/stop timer or +1) right where the status is shown. While a timer
/// runs the value counts live and the stop symbol pulses in the metric's
/// color. The metric color is reserved for the action and the data ink;
/// the rest of the card stays monochrome.
struct MetricCardView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let runningSession: Session?
    @State private var showingCountEntry = false
    @State private var showingCountdownPicker = false
    @State private var quickLogTrigger = false

    var body: some View {
        content(SessionStatistics.dailyTotals(from: metric.sessions))
            .sheet(isPresented: $showingCountEntry) {
                CountEntryView(metric: metric, project: nil)
            }
            .sheet(isPresented: $showingCountdownPicker) {
                CountdownStartView(metric: metric)
            }
            .sensoryFeedback(.increase, trigger: quickLogTrigger)
            .recordingFeedback(isActive: runningSession != nil)
    }

    private func content(_ totals: [DailyTotal]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            valueRow(totals)
            streakLine(totals)
            if let goal = metric.dailyGoal {
                goalBar(
                    today: SessionStatistics.todayTotal(from: totals),
                    goal: goal
                )
            }
        }
        .cardSurface()
    }
}

// MARK: - Card Pieces

extension MetricCardView {
    private var tint: Color {
        metric.displayColor
    }

    private var header: some View {
        HStack(spacing: 12) {
            MetricIcon(systemName: metric.displayIcon, tint: tint)
            Text(metric.name)
                .font(.headline)
            Spacer()
            actionButton
        }
    }

    private func valueRow(_ totals: [DailyTotal]) -> some View {
        HStack(alignment: .lastTextBaseline, spacing: 16) {
            todayValue(totals)
                .numeralStyle(.value)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Spacer()
            SparklineView(
                values: SessionStatistics.trailingDailySeries(
                    days: 7, from: totals
                ),
                tint: tint
            )
            .frame(width: 92, height: 26)
        }
    }

    @ViewBuilder
    private func todayValue(_ totals: [DailyTotal]) -> some View {
        if metric.measurementType == .binary {
            Text(SessionStatistics.todayTotal(from: totals) > 0 ? "Done" : "Not yet")
        } else if let session = runningSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(
                    backdatedBy: SessionStatistics.todayTotal(from: totals)
                )
            )
        } else {
            Text(
                ValueFormatter.format(
                    SessionStatistics.todayTotal(from: totals),
                    type: metric.measurementType,
                    unit: metric.unit
                )
            )
        }
    }

    private func streakLine(_ totals: [DailyTotal]) -> some View {
        let streak = SessionStatistics.currentStreak(
            from: totals,
            excludedWeekdays: metric.excludedWeekdaySet
        )
        let suffix = streak > 1 ? " · \(streak) day streak" : ""
        return Text("today\(suffix)")
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func goalBar(
        today: TimeInterval,
        goal: TimeInterval
    ) -> some View {
        let fraction = min(today / max(goal, 1), 1)
        return HStack(spacing: 12) {
            ProgressTrack(fraction: fraction, tint: tint)
                .frame(height: 6)
            Text(goalLabel(goal, reached: fraction >= 1))
                .font(.caption)
                .foregroundStyle(fraction >= 1 ? tint : .secondary)
                .layoutPriority(1)
        }
    }

    private func goalLabel(_ goal: TimeInterval, reached: Bool) -> String {
        if reached {
            return "goal reached"
        }
        let amount = ValueFormatter.formatShort(goal, type: metric.measurementType)
        return "goal \(amount)"
    }
}

// MARK: - Actions

extension MetricCardView {
    @ViewBuilder
    private var actionButton: some View {
        switch metric.measurementType {
        case .duration:
            timerButton
        case .count:
            countButton
        case .binary:
            binaryButton
        }
    }

    /// Tap toggles today between done and not done; binary metrics hold at
    /// most one entry per day.
    private var binaryButton: some View {
        Button(action: toggleDone) {
            actionIcon(isDoneToday ? "checkmark" : "circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDoneToday ? "Mark not done today" : "Mark done today")
    }

    private var isDoneToday: Bool {
        SessionStatistics.todayTotal(from: metric.sessions) > 0
    }

    /// Tap starts (or stops) a count-up timer; the menu offers count-down
    /// lengths instead — the same start-time choice the hero shows.
    @ViewBuilder
    private var timerButton: some View {
        if runningSession == nil {
            Menu {
                CountdownOptionsMenu(
                    onPreset: startCountdown,
                    onCustom: { showingCountdownPicker = true }
                )
            } label: {
                actionIcon("play.fill")
            } primaryAction: {
                toggleTimer()
            }
            .accessibilityLabel("Start Timer")
        } else {
            Button(action: toggleTimer) {
                actionIcon("stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Timer")
        }
    }

    /// Tap logs one unit instantly; long-press offers the custom-amount sheet.
    private var countButton: some View {
        Menu {
            Button {
                showingCountEntry = true
            } label: {
                Label("Log Custom Amount", systemImage: "square.and.pencil")
            }
        } label: {
            actionIcon("plus")
        } primaryAction: {
            logOne()
        }
        .accessibilityLabel("Log one \(metric.unit ?? "entry")")
    }

    private func actionIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .symbolEffect(.pulse, isActive: runningSession != nil)
            .frame(width: 36, height: 36)
            .background(Circle().fill(tint))
    }

    private func toggleTimer() {
        withAnimation {
            SessionService.toggleSession(
                for: metric,
                runningSession: runningSession,
                in: modelContext
            )
        }
    }

    private func startCountdown(_ duration: TimeInterval) {
        withAnimation {
            SessionService.startSession(
                for: metric,
                in: modelContext,
                countdownDuration: duration
            )
        }
    }

    private func logOne() {
        withAnimation {
            SessionService.logCount(1, for: metric, in: modelContext)
        }
        quickLogTrigger.toggle()
    }

    private func toggleDone() {
        withAnimation {
            SessionService.toggleBinaryDay(for: metric, in: modelContext)
        }
        quickLogTrigger.toggle()
    }
}
