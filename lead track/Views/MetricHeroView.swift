import SwiftData
import SwiftUI

/// The hero header of the metric detail screen: today's value in large
/// rounded digits with its daily-goal progress right underneath, the primary
/// record action as a full-width capsule, and the secondary ways to record —
/// counting down, logging by hand — as one row of equally weighted tinted
/// buttons below it.
struct MetricHeroView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let activeSession: Session?
    let todayTotal: TimeInterval
    let onLogManually: () -> Void
    @State private var quickLogTrigger = false
    @State private var showingCountdownPicker = false
    @State private var isSyncingHealth = false

    var body: some View {
        VStack(spacing: 20) {
            heroValue
            if metric.isHealthLinked {
                healthProvenance
            } else {
                primaryButton
                secondaryActions
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .sensoryFeedback(.increase, trigger: quickLogTrigger)
        .sheet(isPresented: $showingCountdownPicker) {
            CountdownStartView(metric: metric)
        }
    }

    /// Counting down is only offered before a timer is running, and only for
    /// duration metrics — count metrics have no timer.
    private var showsCountdownStart: Bool {
        metric.measurementType == .duration && activeSession == nil
    }
}

// MARK: - Value

extension MetricHeroView {
    private var heroValue: some View {
        VStack(spacing: 6) {
            valueText
                .numeralStyle(.hero)
                .foregroundStyle(metric.displayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: activeSession?.countsDown ?? false))
            goalProgress
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if metric.measurementType == .binary {
            Image(systemName: isDoneToday ? "checkmark.circle.fill" : "circle")
        } else if let session = activeSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(backdatedBy: todayTotal)
            )
        } else {
            Text(ValueFormatter.formatShort(todayTotal, type: metric.measurementType))
        }
    }

    /// The daily goal graded right under the number it applies to — the
    /// statistics card below no longer repeats today's value.
    @ViewBuilder
    private var goalProgress: some View {
        if let fraction = goalFraction {
            ProgressTrack(fraction: fraction, tint: metric.displayColor)
                .frame(width: 160, height: 5)
        }
    }

    /// Progress toward the daily goal, nil whenever there is nothing to
    /// grade: no goal set, a binary metric, or a rest day.
    private var goalFraction: Double? {
        guard metric.measurementType.tracksQuantity,
              let goal = metric.dailyGoal, goal > 0, !isRestDay
        else { return nil }
        return min(todayTotal / goal, 1)
    }

    private var isRestDay: Bool {
        metric.excludedWeekdays.contains(
            Calendar.current.component(.weekday, from: .now)
        )
    }

    private var caption: String {
        if metric.measurementType == .binary {
            return isDoneToday ? "done today" : "not done yet"
        }
        if let goal = metric.dailyGoal, metric.measurementType.tracksQuantity {
            return goalCaption(goal)
        }
        return unitCaption
    }

    /// "55% of 30m 00s today", or the rest-day note when today is excluded.
    private func goalCaption(_ goal: TimeInterval) -> String {
        guard !isRestDay else { return "rest day" }
        let percent = Int(min(todayTotal / max(goal, 1), 1) * 100)
        let target = ValueFormatter.format(goal, type: metric.measurementType, unit: metric.unit)
        return "\(percent)% of \(target) today"
    }

    private var unitCaption: String {
        guard metric.measurementType == .count,
              let unit = metric.unit, !unit.isEmpty
        else { return "today" }
        return "\(unit) today"
    }

    /// Whether today already counts as done for a binary metric.
    private var isDoneToday: Bool {
        todayTotal > 0
    }
}

// MARK: - Actions

extension MetricHeroView {
    @ViewBuilder
    private var primaryButton: some View {
        switch metric.measurementType {
        case .duration:
            timerButton
        case .count:
            countButton
        case .binary:
            binaryButton
        }
    }

    private var binaryButton: some View {
        Button(action: toggleDone) {
            Label(
                isDoneToday ? "Done" : "Mark Done",
                systemImage: isDoneToday ? "checkmark.circle.fill" : "circle"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(metric.prominentColor)
    }

    private var timerButton: some View {
        Button(action: toggleTimer) {
            Label(
                activeSession == nil ? "Start" : "Stop",
                systemImage: activeSession == nil ? "play.fill" : "stop.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(metric.prominentColor)
    }

    private var countButton: some View {
        Button(action: logOne) {
            Label("Log +1", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(metric.prominentColor)
    }

    /// The quieter ways to record, one row, equal visual weight — neither
    /// reads as disabled the way the old gray text button did.
    @ViewBuilder
    private var secondaryActions: some View {
        if showsCountdownStart || metric.measurementType.tracksQuantity {
            HStack(spacing: 24) {
                if showsCountdownStart {
                    countdownButton
                }
                if metric.measurementType.tracksQuantity {
                    manualLogButton
                }
            }
        }
    }

    /// The visible alternative to the count-up "Start": pick a length and the
    /// timer counts down from it.
    private var countdownButton: some View {
        Menu {
            CountdownOptionsMenu(
                onPreset: startCountdown,
                onCustom: { showingCountdownPicker = true }
            )
        } label: {
            Label("Start Countdown", systemImage: "timer")
                .font(.subheadline)
        }
        .tint(metric.displayColor)
    }

    private var manualLogButton: some View {
        Button(action: onLogManually) {
            Label(manualLogTitle, systemImage: "square.and.pencil")
                .font(.subheadline)
        }
        .tint(metric.displayColor)
    }

    /// Health metrics record themselves, so the action slot offers a manual
    /// sync instead — which also re-asks for read access if the permission
    /// sheet was dismissed unanswered.
    private var healthProvenance: some View {
        VStack(spacing: 8) {
            Label("From Apple Health", systemImage: "heart.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button("Sync Now", action: syncNow)
                .font(.subheadline)
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

    private var manualLogTitle: String {
        metric.measurementType == .duration ? "Log Manually" : "Log Custom Amount"
    }

    private func toggleTimer() {
        withAnimation {
            SessionService.toggleSession(
                for: metric,
                runningSession: activeSession,
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

// MARK: - Button Style

private struct ProminentCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        content.buttonStyle(.glassProminent)
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}

extension View {
    /// Liquid-glass prominent capsule on iOS 26 toolchains, falling back to
    /// bordered prominent where the SDK predates glass (CI's Xcode 16).
    func prominentCapsuleButtonStyle() -> some View {
        modifier(ProminentCapsuleStyle())
            .buttonBorderShape(.capsule)
            .controlSize(.large)
    }
}
