import SwiftData
import SwiftUI

/// The floating record dock pinned under the metric detail: the primary
/// record action as a prominent capsule — start/stop for timers, log +1 for
/// counts, mark done for habits — with the quieter ways to record as glass
/// circles beside it. Health-linked metrics record themselves, so their
/// detail shows no dock at all.
struct MetricRecordDock: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let activeSession: Session?
    let onLogManually: () -> Void
    @State private var quickLogTrigger = false
    @State private var showingCountdownPicker = false

    var body: some View {
        HStack(spacing: 10) {
            primaryPill
            if showsCountdownStart {
                countdownButton
            }
            if metric.measurementType.tracksQuantity {
                secondaryLogButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
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

// MARK: - Primary Action

extension MetricRecordDock {
    @ViewBuilder
    private var primaryPill: some View {
        switch metric.measurementType {
        case .duration:
            pill(
                activeSession == nil ? "Start" : "Stop",
                systemImage: activeSession == nil ? "play.fill" : "stop.fill",
                action: toggleTimer
            )
        case .count:
            countPill
        case .binary:
            pill(
                isDoneToday ? "Done" : "Mark Done",
                systemImage: isDoneToday ? "checkmark.circle.fill" : "circle",
                action: toggleDone
            )
        }
    }

    /// The count pill follows the metric's log style — ask for the amount,
    /// or add one on the spot. The glass circle beside it keeps the other.
    @ViewBuilder
    private var countPill: some View {
        if metric.logsOneUnitImmediately {
            pill("Log +1", systemImage: "plus", action: logOne)
        } else {
            pill("Log", systemImage: "square.and.pencil", action: onLogManually)
        }
    }

    private var isDoneToday: Bool {
        SessionStatistics.todayTotal(from: metric.sessions) > 0
    }

    private func pill(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(metric.prominentColor)
    }
}

// MARK: - Glass Circles

extension MetricRecordDock {
    /// The visible alternative to the count-up "Start": pick a length and the
    /// timer counts down from it.
    private var countdownButton: some View {
        Menu {
            CountdownOptionsMenu(
                onPreset: startCountdown,
                onCustom: { showingCountdownPicker = true }
            )
        } label: {
            circleLabel("timer")
        }
        .glassCircleButtonStyle()
        .tint(metric.displayColor)
        .accessibilityLabel("Start Countdown")
    }

    /// A count metric whose primary pill asks for the amount keeps the quick
    /// +1 here instead of a second way into the same sheet; everything else
    /// keeps the manual-entry pencil.
    @ViewBuilder
    private var secondaryLogButton: some View {
        if metric.measurementType == .count, !metric.logsOneUnitImmediately {
            quickLogOneButton
        } else {
            manualLogButton
        }
    }

    private var quickLogOneButton: some View {
        Button(action: logOne) {
            circleLabel("plus")
        }
        .glassCircleButtonStyle()
        .tint(metric.displayColor)
        .accessibilityLabel("Log +1")
    }

    private var manualLogButton: some View {
        Button(action: onLogManually) {
            circleLabel("square.and.pencil")
        }
        .glassCircleButtonStyle()
        .tint(metric.displayColor)
        .accessibilityLabel(
            metric.measurementType == .duration ? "Log Manually" : "Log Custom Amount"
        )
    }

    private func circleLabel(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.medium))
            .frame(width: 26, height: 26)
    }
}

// MARK: - Actions

extension MetricRecordDock {
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

// MARK: - Button Styles

private struct ProminentCapsuleStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        content.buttonStyle(.glassProminent)
        #else
        content.buttonStyle(.borderedProminent)
        #endif
    }
}

private struct GlassCircleStyle: ViewModifier {
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        content
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
        #else
        content
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
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

    /// A round liquid-glass button for the dock's secondary record actions,
    /// with the same pre-glass fallback as the capsule.
    fileprivate func glassCircleButtonStyle() -> some View {
        modifier(GlassCircleStyle())
            .controlSize(.large)
    }
}
