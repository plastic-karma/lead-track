import SwiftData
import SwiftUI

/// The record-action quartet — start/stop the timer, start a countdown, log
/// +1, mark today done — in one place, so every surface that records (the
/// metric detail dock, the Today cluster rows) shares the same service
/// calls, animation, and haptic trigger instead of drifting apart.
@MainActor
struct MetricRecorder {
    /// The one deliberate record animation: `.snappy`, the quick in-place
    /// feel the Today rows established. Every surface records with it.
    static let animation = Animation.snappy

    let metric: Metric
    let runningSession: Session?
    let modelContext: ModelContext
    /// Fired after an instant log (+1, mark done) so the surface can flip
    /// its `sensoryFeedback` trigger.
    let onQuickLog: () -> Void

    /// Whether the metric already recorded anything today — the binary
    /// action's checked state.
    var isDoneToday: Bool {
        SessionStatistics.todayTotal(from: metric.sessions) > 0
    }

    func toggleTimer() {
        withAnimation(Self.animation) {
            SessionService.toggleSession(
                for: metric,
                runningSession: runningSession,
                in: modelContext
            )
        }
    }

    func startCountdown(_ duration: TimeInterval) {
        withAnimation(Self.animation) {
            SessionService.startSession(
                for: metric,
                in: modelContext,
                countdownDuration: duration
            )
        }
    }

    func logOne() {
        withAnimation(Self.animation) {
            SessionService.logCount(1, for: metric, in: modelContext)
        }
        onQuickLog()
    }

    func toggleDone() {
        withAnimation(Self.animation) {
            SessionService.toggleBinaryDay(for: metric, in: modelContext)
        }
        onQuickLog()
    }
}
