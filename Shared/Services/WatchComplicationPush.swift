import Foundation

/// Decides whether the phone spends a complication transfer to wake the watch
/// so its complications refresh themselves.
///
/// `transferCurrentComplicationUserInfo` is the only WatchConnectivity delivery
/// that wakes a suspended watch app in the background to reload its complication
/// timelines — `updateApplicationContext` reaches the watch only once the app is
/// next opened, which is why complications otherwise look frozen until tapped.
/// But complication transfers draw on a small daily budget, so a wake is spent
/// only when a complication is actually on the active face, budget remains, and
/// a leading-edge interval has passed since the last wake. That collapses a
/// burst of rapid logs into a single wake while still waking instantly on the
/// first change, keeping the day's budget for changes that come later.
enum WatchComplicationPush {
    /// Shortest gap between background wakes; changes inside it coalesce into
    /// the wake already spent. Discrete actions the user cares about (a timer
    /// start or stop, an evening log) sit far enough apart to always wake.
    static let minWakeInterval: TimeInterval = 90

    static func shouldWake(
        complicationEnabled: Bool,
        remainingTransfers: Int,
        secondsSinceLastWake: TimeInterval,
        minInterval: TimeInterval
    ) -> Bool {
        complicationEnabled && remainingTransfers > 0 && secondsSinceLastWake >= minInterval
    }
}
