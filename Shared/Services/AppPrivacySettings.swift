import Foundation

/// Privacy choices shared by the app and its extensions. The app lock used to
/// live in the containing app's standard defaults domain; extensions cannot
/// read that domain, so the current contract lives in the App Group instead.
enum AppPrivacySettings {
    static let appLockEnabledKey = "appLockEnabled"
    static let appLockGracePeriodKey = "appLockGracePeriod"

    /// The same suite `@AppStorage`, notification planning, and extensions use.
    static var store: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }

    /// Copies pre-App-Group values forward without ever overwriting a value
    /// already written to the shared domain. It is therefore safe to run on
    /// every app launch and preserves a later change made in either the app or
    /// an extension. When the old domain has no value, materializing the
    /// defaults distinguishes a migrated unlocked app from an uninitialized
    /// extension process.
    static func migrateLegacyValues(
        from legacy: UserDefaults = .standard,
        to shared: UserDefaults = store
    ) {
        migrate(appLockEnabledKey, defaultValue: false, from: legacy, to: shared)
        migrate(appLockGracePeriodKey, defaultValue: 0, from: legacy, to: shared)
    }

    static func isAppLockEnabled(in defaults: UserDefaults = store) -> Bool {
        defaults.bool(forKey: appLockEnabledKey)
    }

    /// Shared consumers fail closed until the containing app has migrated its
    /// legacy standard defaults. A missing key can mean an upgrade where an
    /// extension or notification path ran before the updated app's first launch.
    static func shouldProtectSharedContent(
        in defaults: UserDefaults = store
    ) -> Bool {
        guard let enabled = defaults.object(forKey: appLockEnabledKey) as? Bool else { return true }
        return enabled
    }

    static func requiresAuthenticationForExtension(
        in defaults: UserDefaults = store
    ) -> Bool {
        shouldProtectSharedContent(in: defaults)
    }

    static func appLockGracePeriod(in defaults: UserDefaults = store) -> Int {
        defaults.integer(forKey: appLockGracePeriodKey)
    }

    private static func migrate(
        _ key: String,
        defaultValue: Any,
        from legacy: UserDefaults,
        to shared: UserDefaults
    ) {
        guard shared.object(forKey: key) == nil else { return }
        shared.set(legacy.object(forKey: key) ?? defaultValue, forKey: key)
    }
}
