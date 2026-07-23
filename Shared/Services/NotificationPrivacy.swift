import Foundation

/// Whether notification banners should avoid user content. When the Face ID
/// app lock is on, the lock screen must not broadcast what the lock protects
/// — metric names, streak counts, the user's own intention questions — so
/// every banner falls back to generic copy.
enum NotificationPrivacy {
    static func isDiscreet(
        in defaults: UserDefaults = AppPrivacySettings.store
    ) -> Bool {
        AppPrivacySettings.shouldProtectSharedContent(in: defaults)
    }
}
