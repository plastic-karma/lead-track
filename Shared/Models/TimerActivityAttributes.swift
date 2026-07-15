// canImport(ActivityKit) is true on macOS, but the API is unavailable
// there — the macOS overlay build must skip this file's contents.
#if canImport(ActivityKit) && !os(macOS)
import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }

    var metricName: String
    /// The metric's stable ID (uuidString) — the identity StopTimerIntent
    /// matches on; `metricName` is display-only. Optional so activities
    /// started by builds that predate the field still rehydrate.
    var metricID: String?
    var projectName: String?
    var icon: String
    var colorName: String?
    /// Seconds a countdown timer runs for, or nil when the metric counts up.
    var countdownDuration: TimeInterval?

    /// The range a countdown started at `startedAt` animates across, or nil
    /// for a count-up timer.
    func countdownInterval(startedAt: Date) -> ClosedRange<Date>? {
        CountdownDisplay.interval(startedAt: startedAt, duration: countdownDuration)
    }
}
#endif
