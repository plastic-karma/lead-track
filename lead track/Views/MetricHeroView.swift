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

    var body: some View {
        VStack(spacing: 20) {
            heroValue
            primaryButton
            manualLogButton
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .sensoryFeedback(.increase, trigger: quickLogTrigger)
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
                .contentTransition(.numericText())
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// While a timer runs, the origin is backdated by today's completed
    /// total so the counting value shows the whole day, not just the
    /// current session.
    @ViewBuilder
    private var valueText: some View {
        if let session = activeSession {
            Text(
                session.startedAt.addingTimeInterval(-todayTotal),
                style: .timer
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
        .tint(activeSession == nil ? metric.displayColor : .red)
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
            if let session = activeSession {
                SessionService.stopSession(session)
            } else {
                SessionService.startSession(for: metric, in: modelContext)
            }
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
