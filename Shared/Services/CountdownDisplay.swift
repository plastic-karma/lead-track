import Foundation

/// The one countdown display rule: a positive target counts down across
/// `start ... start + target`; anything else counts up (nil). `Session`,
/// the Live Activity attributes, and the watch snapshot all delegate here
/// so the rule can't drift across the three targets that render timers.
enum CountdownDisplay {
    static func interval(
        startedAt: Date,
        duration: TimeInterval?
    ) -> ClosedRange<Date>? {
        guard let duration, duration > 0 else { return nil }
        return startedAt ... startedAt.addingTimeInterval(duration)
    }
}
