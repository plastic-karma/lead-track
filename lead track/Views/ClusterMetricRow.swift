import SwiftData
import SwiftUI

/// One metric's row inside a Today cluster card. An active row carries the
/// identity icon, the day's value against its goal over a slim progress
/// track, and a 44 pt circular action — the same one-tap start/log/check the
/// old full-width button offered, just quiet. A done row folds in place to a
/// checkmark and its final value instead of moving to a bottom section.
/// Tapping the row still navigates to the metric's detail screen. On a
/// browsed earlier day the row is testimony, not a control: the action
/// circle stays home and the figures read as that day closed.
struct ClusterMetricRow: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let runningSession: Session?
    /// The day the row reads — recording is only offered when it is today.
    let day: Date
    @State private var showingCountEntry = false
    @State private var showingCountdownPicker = false
    @State private var showingDeleteConfirmation = false
    @State private var quickLogTrigger = false

    var body: some View {
        // One pass over the session history per render; every consumer below
        // (value line, progress track, done row, binary action) shares it.
        let total = todayTotal
        return NavigationLink(value: metric) {
            row(total)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                Label("Delete Metric", systemImage: "trash")
            }
        }
        .confirmationDialog(
            "Delete \(metric.name)?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Metric", role: .destructive) {
                withAnimation(.snappy) { modelContext.delete(metric) }
            }
        } message: {
            Text("All of its logged sessions and projects are deleted with it. This can't be undone.")
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
    private func row(_ total: TimeInterval) -> some View {
        if GoalSummary.isDailyComplete(metric, now: day), runningSession == nil {
            doneRow(total)
        } else {
            activeRow(total)
        }
    }

    /// The shared record actions — the row supplies only layout.
    private var recorder: MetricRecorder {
        MetricRecorder(
            metric: metric,
            runningSession: runningSession,
            modelContext: modelContext
        ) {
            quickLogTrigger.toggle()
        }
    }
}

// MARK: - Active Row

extension ClusterMetricRow {
    private func activeRow(_ total: TimeInterval) -> some View {
        HStack(alignment: .center, spacing: 12) {
            MetricIcon(systemName: metric.displayIcon, tint: metric.displayColor, size: 30)
            VStack(alignment: .leading, spacing: 5) {
                valueLine(total)
                if let fraction = goalFraction(total) {
                    ProgressTrack(fraction: fraction, tint: metric.displayColor)
                        .frame(height: 4)
                }
            }
            if !metric.isHealthLinked, Calendar.current.isDateInToday(day) {
                actionButton(total)
            }
        }
        .padding(.vertical, 12)
    }

    private func valueLine(_ total: TimeInterval) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(metric.name)
                .font(.headline)
                .lineLimit(1)
            Spacer(minLength: 6)
            todayValue(total)
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
    private func todayValue(_ total: TimeInterval) -> some View {
        if metric.measurementType == .binary {
            Text(total > 0 ? "Done" : "Not yet")
        } else if let session = runningSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(backdatedBy: total)
            )
        } else {
            Text(ValueFormatter.formatShort(total, type: metric.measurementType))
        }
    }

    /// Durations wear the compact form ("of 3m") — the row is dense and the
    /// remaining seconds live in the insight line, not the target.
    private var goalText: String? {
        guard metric.measurementType.tracksQuantity, let goal = metric.dailyGoal
        else { return nil }
        if metric.measurementType == .duration {
            return DurationFormatter.compact(goal)
        }
        return ValueFormatter.format(goal, type: metric.measurementType, unit: metric.unit)
    }

    /// Today's completion (0–1) toward a quantity goal — the row's slim
    /// track. Derived from the hoisted total (the same arithmetic as
    /// `TodayGrouping.completionFraction`) so the row never re-scans the
    /// session history for it.
    private func goalFraction(_ total: TimeInterval) -> Double? {
        guard metric.measurementType.tracksQuantity, let goal = metric.dailyGoal
        else { return nil }
        guard goal > 0 else { return 0 }
        return min(total / goal, 1)
    }

    private var todayTotal: TimeInterval {
        SessionStatistics.todayTotal(from: metric.sessions, now: day)
    }
}

// MARK: - Done Row

extension ClusterMetricRow {
    private func doneRow(_ total: TimeInterval) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(metric.displayColor)
                .frame(width: 30)
            Text(metric.name)
                .font(.callout.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(ValueFormatter.format(total, type: metric.measurementType, unit: metric.unit))
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
    private func actionButton(_ total: TimeInterval) -> some View {
        switch metric.measurementType {
        case .duration:
            timerButton
        case .count:
            countButton
        case .binary:
            binaryButton(total)
        }
    }

    /// Tap starts (count-up) or stops the timer; the menu offers count-down
    /// lengths instead — the same choices as the metric hero.
    @ViewBuilder
    private var timerButton: some View {
        if runningSession == nil {
            Menu {
                CountdownOptionsMenu(
                    onPreset: recorder.startCountdown,
                    onCustom: { showingCountdownPicker = true }
                )
            } label: {
                actionCircle("play.fill")
            } primaryAction: {
                recorder.toggleTimer()
            }
            .accessibilityLabel("Start Timer")
        } else {
            Button(action: recorder.toggleTimer) {
                actionCircle("stop.fill")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop Timer")
        }
    }

    /// Tap follows the metric's log style — open the custom-amount sheet, or
    /// add one right away — and the menu keeps the other route.
    private var countButton: some View {
        Menu {
            countMenuAlternative
        } label: {
            actionCircle("plus")
        } primaryAction: {
            if metric.logsOneUnitImmediately {
                recorder.logOne()
            } else {
                showingCountEntry = true
            }
        }
        .accessibilityLabel("Log \(metric.unit ?? "amount")")
    }

    @ViewBuilder
    private var countMenuAlternative: some View {
        if metric.logsOneUnitImmediately {
            Button {
                showingCountEntry = true
            } label: {
                Label("Log Amount…", systemImage: "square.and.pencil")
            }
        } else {
            Button {
                recorder.logOne()
            } label: {
                Label("Log +1", systemImage: "plus")
            }
        }
    }

    private func binaryButton(_ total: TimeInterval) -> some View {
        Button(action: recorder.toggleDone) {
            actionCircle(total > 0 ? "checkmark" : "circle")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(total > 0 ? "Mark not done today" : "Mark done today")
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
