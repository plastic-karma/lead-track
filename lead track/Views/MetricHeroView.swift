import SwiftData
import SwiftUI

/// The hero header of the metric detail screen: today's value in large
/// rounded digits tinted with the metric's color, the primary record action
/// as a full-width capsule right below it, and manual logging demoted to a
/// quiet text button.
struct MetricHeroView: View {
    @Environment(\.modelContext) private var modelContext
    let metric: Metric
    let activeSession: Session?
    let todayTotal: TimeInterval
    let onLogManually: () -> Void
    @State private var quickLogTrigger = false
    @State private var showingCountdownPicker = false

    var body: some View {
        VStack(spacing: 20) {
            heroValue
            primaryButton
            if showsCountdownStart {
                countdownButton
            }
            manualLogButton
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
        VStack(spacing: 4) {
            valueText
                .numeralStyle(.hero)
                .foregroundStyle(metric.displayColor)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .contentTransition(.numericText(countsDown: activeSession?.countsDown ?? false))
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var valueText: some View {
        if let session = activeSession {
            Text(
                liveTimer: session.countdownInterval,
                countingUpFrom: session.liveTimerOrigin(backdatedBy: todayTotal)
            )
        } else {
            Text(ValueFormatter.formatShort(todayTotal, type: metric.measurementType))
        }
    }

    private var caption: String {
        guard metric.measurementType == .count,
              let unit = metric.unit, !unit.isEmpty
        else { return "today" }
        return "\(unit) today"
    }
}

// MARK: - Actions

extension MetricHeroView {
    @ViewBuilder
    private var primaryButton: some View {
        if metric.measurementType == .duration {
            timerButton
        } else {
            countButton
        }
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
        .tint(metric.displayColor)
    }

    private var countButton: some View {
        Button(action: logOne) {
            Label("Log +1", systemImage: "plus")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .prominentCapsuleButtonStyle()
        .tint(metric.displayColor)
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
        Button(manualLogTitle, action: onLogManually)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .buttonStyle(.plain)
    }

    private var manualLogTitle: String {
        metric.measurementType == .duration ? "Log manually" : "Log custom amount"
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
