import Foundation

/// The weekly-review notification's UserDefaults contract — key names and
/// defaults in one place, so the settings sheet's `@AppStorage` bindings and
/// `NotificationService`'s scheduler can never drift apart.
enum WeeklyReviewSettings {
    static let enabledKey = "weeklyReviewEnabled"
    static let dayKey = "weeklyReviewDay"
    static let hourKey = "weeklyReviewHour"
    static let minuteKey = "weeklyReviewMinute"

    /// Monday, in `Calendar`'s 1 = Sunday weekday numbering.
    static let defaultDay = 2
    static let defaultHour = 9
    static let defaultMinute = 0

    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func day(in defaults: UserDefaults = .standard) -> Int {
        integer(forKey: dayKey, default: defaultDay, in: defaults)
    }

    static func hour(in defaults: UserDefaults = .standard) -> Int {
        integer(forKey: hourKey, default: defaultHour, in: defaults)
    }

    static func minute(in defaults: UserDefaults = .standard) -> Int {
        integer(forKey: minuteKey, default: defaultMinute, in: defaults)
    }

    /// One read idiom for every numeric key: an absent key means the user
    /// never touched the setting, so the default applies; any stored value —
    /// zero included — wins as-is.
    private static func integer(
        forKey key: String,
        default fallback: Int,
        in defaults: UserDefaults
    ) -> Int {
        defaults.object(forKey: key) as? Int ?? fallback
    }
}
