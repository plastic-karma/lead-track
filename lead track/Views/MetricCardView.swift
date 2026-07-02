import SwiftData
import SwiftUI

/// One dashboard card per active metric: identity, today's value against its
/// goal with a progress bar, and a full-width primary action (start/resume/stop
/// the timer, or log a count). While a timer runs the value counts live and the
/// action pulses in the metric's color. The metric color is reserved for the
/// action and the data ink; the rest of the card stays monochrome.
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
        let today = SessionStatistics.todayTotal(from: totals)
        return VStack(alignment: .leading, spacing: 14) {
            header
            valueRow(totals)
            if let goal = metric.dailyGoal {
                ProgressTrack(fraction: min(today / max(goal, 1), 1), tint: tint)
                    .frame(height: 6)
            }
            if metric.isHealthLinked {
                healthAttribution
            } else {
                actionButton(today: today)
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
                .font(.title3.weight(.bold))
            Spacer()
        }
    }

    private func valueRow(_ totals: [DailyTotal]) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            todayValue(totals)
                .numeralStyle(.value)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let goal = metric.dailyGoal {
                Text("of")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(ValueFormatter.format(goal, type: metric.measurementType, unit: metric.unit))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
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
}

// MARK: - Actions

extension MetricCardView {
    /// Health-linked cards act nowhere — the day fills itself from Apple
    /// Health — so the action slot shows provenance instead of a button.
    private var healthAttribution: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
            Text("From Apple Health")
            Spacer()
            if let synced = metric.lastHealthSyncAt {
                Text("Updated \(synced, format: .relative(presentation: .named))")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func actionButton(today: TimeInterval) -> some View {
        switch metric.measurementType {
        case .duration:
            timerButton(today: today)
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
            actionLabel(
                isDoneToday ? "checkmark" : "circle",
                isDoneToday ? "Done" : "Mark Done"
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isDoneToday ? "Mark not done today" : "Mark done today")
    }

    private var isDoneToday: Bool {
        SessionStatistics.todayTotal(from: metric.sessions) > 0
    }

    /// Tap starts (count-up) or stops the timer; the menu offers count-down
    /// lengths instead. The verb reflects the day's progress: Start from zero,
    /// Resume once there's time on the clock.
    @ViewBuilder
    private func timerButton(today: TimeInterval) -> some View {
        if runningSession == nil {
            Menu {
                CountdownOptionsMenu(
                    onPreset: startCountdown,
                    onCustom: { showingCountdownPicker = true }
                )
            } label: {
                actionLabel("play.fill", today > 0 ? "Resume" : "Start")
            } primaryAction: {
                toggleTimer()
            }
            .accessibilityLabel("Start Timer")
        } else {
            Button(action: toggleTimer) {
                actionLabel("stop.fill", "Stop")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Timer")
        }
    }

    /// Tap logs one unit instantly; the menu offers the custom-amount sheet.
    private var countButton: some View {
        Menu {
            Button {
                showingCountEntry = true
            } label: {
                Label("Log Custom Amount", systemImage: "square.and.pencil")
            }
        } label: {
            actionLabel("plus", "Log")
        } primaryAction: {
            logOne()
        }
        .accessibilityLabel("Log one \(metric.unit ?? "entry")")
    }

    /// The fill is the deeper prominent variant, not the identity tint, so
    /// the white label keeps 4.5:1 contrast in both color schemes.
    private func actionLabel(_ systemName: String, _ title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemName)
            Text(title)
        }
        .font(.headline)
        .foregroundStyle(.white)
        .symbolEffect(.pulse, isActive: runningSession != nil)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(metric.prominentColor)
                .shadow(color: metric.prominentColor.opacity(0.5), radius: 8)
        )
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
