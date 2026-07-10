import Foundation

/// The home-screen widgets' shared refresh cadence — one place to tune it
/// for both providers.
enum WidgetTimeline {
    static let refreshInterval: TimeInterval = 15 * 60

    /// The next periodic refresh instant.
    static func nextUpdate(after now: Date = .now) -> Date {
        now.addingTimeInterval(refreshInterval)
    }
}
