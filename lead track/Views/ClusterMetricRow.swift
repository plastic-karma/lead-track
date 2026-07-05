import SwiftData
import SwiftUI

/// One metric's row inside a Today cluster card. An active row carries the
/// identity icon, today's value against its goal over a slim progress track,
/// and a 44 pt circular action — the same one-tap start/log/check the old
/// full-width button offered, just quiet. A done row folds in place to a
/// checkmark and its final value instead of moving to a bottom section.
/// Tapping the row still navigates to the metric's detail screen.
struct ClusterMetricRow: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let runningSession: Session?
    @State private var showingCountEntry = false
    @State private var showingCountdownPicker = false
    @State private var quickLogTrigger = false

    var body: some View {
        NavigationLink(value: metric) {
            row
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation(.snappy) { modelContext.delete(metric) }
            } label: {
                Label("Delete Metric", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingCountEntry) {
            CountEntryView(metric: metric, project: nil)
        }
        .sheet(isPresented: $showingCountdownPicker) {
            CountdownStartView(metric: metric)
        }
        .sensoryFeedback(.increase, trigger: quickLogTrigger)
        .recordingFeedback(isActive: runningSession != nil)
    }

    /// A met goal quiets the row in place — unless its timer is running,
    /// which keeps the live row so the effort stays stoppable.
    @ViewBuilder
    private var row: some View {
        if GoalSummary.isDailyComplete(metric), runningSession == nil {
            doneRow
        } else {
            activeRow
        }
    }
}

// MARK: - Active Row

extension ClusterMetricRow {
    private var activeRow: some View {
        HStack(alignment: .center, spacing: 12) {
            MetricIcon(systemName: metric.displayIcon, tint: metric.displayColor, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                valueLine
                if let fraction = goalFraction {
                    ProgressTrack(fraction: fraction, tint: metric.displayColor)
                        .frame(height: 4)
                }
            }
            if !metric.isHealthLinked {
                actionButton
            }
        }
        .padding(.vertical, 12)
    }

    private var valueLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.name)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 6)
            todayValue
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .monospacedDigit()
            if let goal = goalText {
                Text("of \(goal)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var todayValue: some View {
        if metric.measurementType == .binary {
            Text(todayTotal > 0 ? "Done" : "Not yet")
        } else if let session = runningSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(backdatedBy: todayTotal)
            )
        } else {
            Text(ValueFormatter.formatShort(todayTotal, type: metric.measurementType))
        }
    }

    private var goalText: String? {
        guard metric.measurementType.tracksQuantity, let goal = metric.dailyGoal
        else { return nil }
        return ValueFormatter.format(goal, type: metric.measurementType, unit: metric.unit)
    }

    private var goalFraction: Double? {
        guard metric.measurementType.tracksQuantity, metric.dailyGoal != nil
        else { return nil }
        return TodayGrouping.completionFraction(metric)
    }

    private var todayTotal: TimeInterval {
        SessionStatistics.todayTotal(from: metric.sessions)
    }
}

// MARK: - Done Row

extension ClusterMetricRow {
    private var doneRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(metric.displayColor)
                .frame(width: 30)
            Text(metric.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(ValueFormatter.format(todayTotal, type: metric.measurementType, unit: metric.unit))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .padding(.trailing, 8)
        }
        .opacity(0.65)
        .padding(.vertical, 11)
    }
}

// MARK: - Action Circle

extension ClusterMetricRow {
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

    /// Tap starts (count-up) or stops the timer; the menu offers count-down
    /// lengths instead — the same choices as the metric hero.
    @ViewBuilder
    private var timerButton: some View {
        if runningSession == nil {
            Menu {
                CountdownOptionsMenu(
                    onPreset: startCountdown,
                    onCustom: { showingCountdownPicker = true }
                )
            } label: {
                actionCircle("play.fill")
            } primaryAction: {
                toggleTimer()
            }
            .accessibilityLabel("Start Timer")
        } else {
            Button(action: toggleTimer) {
                actionCircle("stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Timer")
        }
    }

    /// Tap opens the custom-amount sheet; the menu keeps the quick +1.
    private var countButton: some View {
        Menu {
            Button {
                logOne()
            } label: {
                Label("Log +1", systemImage: "plus")
            }
        } label: {
            actionCircle("plus")
        } primaryAction: {
            showingCountEntry = true
        }
        .accessibilityLabel("Log \(metric.unit ?? "amount")")
    }

    private var binaryButton: some View {
        Button(action: toggleDone) {
            actionCircle(todayTotal > 0 ? "checkmark" : "circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todayTotal > 0 ? "Mark not done today" : "Mark done today")
    }

    /// The quiet action: the metric's glyph-on-wash circle, pulsing gently
    /// while its timer runs.
    private func actionCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(metric.displayColor)
            .symbolEffect(.pulse, isActive: runningSession != nil)
            .frame(width: 44, height: 44)
            .background(Circle().fill(metric.displayColor.opacity(0.15)))
    }
}

// MARK: - Recording

extension ClusterMetricRow {
    private func toggleTimer() {
        withAnimation(.snappy) {
            SessionService.toggleSession(
                for: metric,
                runningSession: runningSession,
                in: modelContext
            )
        }
    }

    private func startCountdown(_ duration: TimeInterval) {
        withAnimation(.snappy) {
            SessionService.startSession(
                for: metric,
                in: modelContext,
                countdownDuration: duration
            )
        }
    }

    private func logOne() {
        withAnimation(.snappy) {
            SessionService.logCount(1, for: metric, in: modelContext)
        }
        quickLogTrigger.toggle()
    }

    private func toggleDone() {
        withAnimation(.snappy) {
            SessionService.toggleBinaryDay(for: metric, in: modelContext)
        }
        quickLogTrigger.toggle()
    }
}
