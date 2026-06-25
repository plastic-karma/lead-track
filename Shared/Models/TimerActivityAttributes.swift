#if canImport(ActivityKit)
import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
    }

    var metricName: String
    var projectName: String?
    var icon: String
    var colorName: String?
    /// Seconds a countdown timer runs for, or nil when the metric counts up.
    var countdownDuration: TimeInterval?

    /// The range a countdown started at `startedAt` animates across, or nil
    /// for a count-up timer.
    func countdownInterval(startedAt: Date) -> ClosedRange<Date>? {
        guard let target = countdownDuration, target > 0 else { return nil }
        return startedAt ... startedAt.addingTimeInterval(target)
    }
}
#endif
