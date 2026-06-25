import Foundation

/// How the app alerts when a countdown reaches zero — a "ping" (sound) and a
/// vibration, each independently switchable. Stored in the shared app-group
/// defaults so the app and the widget extension (which can also start a
/// countdown) read the same choices. Both default to on.
enum CompletionAlertSettings {
    static let soundKey = "countdownCompletionSound"
    static let hapticKey = "countdownCompletionHaptic"

    /// The same suite `@AppStorage` writes to, so reads here see the user's
    /// toggles regardless of which process scheduled the alert.
    static var store: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }

    static var soundEnabled: Bool {
        enabled(soundKey)
    }

    static var hapticEnabled: Bool {
        enabled(hapticKey)
    }

    /// Absent key means the user hasn't touched the toggle yet — default on.
    private static func enabled(_ key: String) -> Bool {
        store.object(forKey: key) as? Bool ?? true
    }
}
