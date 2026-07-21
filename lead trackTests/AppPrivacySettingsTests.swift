import Foundation
import Testing
@testable import lead_track

struct AppPrivacySettingsTests {
    @Test
    func keysKeepTheirStoredContract() {
        #expect(AppPrivacySettings.appLockEnabledKey == "appLockEnabled")
        #expect(AppPrivacySettings.appLockGracePeriodKey == "appLockGracePeriod")
    }

    @Test
    func legacyValuesMigrateIntoEmptySharedDefaults() throws {
        let legacy = try scratchSuite("legacy")
        let shared = try scratchSuite("shared")
        legacy.set(true, forKey: AppPrivacySettings.appLockEnabledKey)
        legacy.set(300, forKey: AppPrivacySettings.appLockGracePeriodKey)

        AppPrivacySettings.migrateLegacyValues(from: legacy, to: shared)

        #expect(AppPrivacySettings.isAppLockEnabled(in: shared))
        #expect(AppPrivacySettings.appLockGracePeriod(in: shared) == 300)
    }

    @Test
    func migrationNeverOverwritesSharedValues() throws {
        let legacy = try scratchSuite("legacy")
        let shared = try scratchSuite("shared")
        legacy.set(true, forKey: AppPrivacySettings.appLockEnabledKey)
        legacy.set(300, forKey: AppPrivacySettings.appLockGracePeriodKey)
        shared.set(false, forKey: AppPrivacySettings.appLockEnabledKey)
        shared.set(60, forKey: AppPrivacySettings.appLockGracePeriodKey)

        AppPrivacySettings.migrateLegacyValues(from: legacy, to: shared)

        #expect(!AppPrivacySettings.isAppLockEnabled(in: shared))
        #expect(AppPrivacySettings.appLockGracePeriod(in: shared) == 60)
    }

    @Test
    func absentLegacyValuesMaterializeUnlockedDefaults() throws {
        let legacy = try scratchSuite("legacy")
        let shared = try scratchSuite("shared")

        AppPrivacySettings.migrateLegacyValues(from: legacy, to: shared)

        #expect(shared.object(forKey: AppPrivacySettings.appLockEnabledKey) != nil)
        #expect(shared.object(forKey: AppPrivacySettings.appLockGracePeriodKey) != nil)
        #expect(!AppPrivacySettings.isAppLockEnabled(in: shared))
        #expect(AppPrivacySettings.appLockGracePeriod(in: shared) == 0)
    }

    @Test
    func extensionFailsClosedUntilSharedPrivacyIsInitialized() throws {
        let shared = try scratchSuite("shared")

        #expect(AppPrivacySettings.requiresAuthenticationForExtension(in: shared))
        shared.set(false, forKey: AppPrivacySettings.appLockEnabledKey)
        #expect(!AppPrivacySettings.requiresAuthenticationForExtension(in: shared))
        shared.set(true, forKey: AppPrivacySettings.appLockEnabledKey)
        #expect(AppPrivacySettings.requiresAuthenticationForExtension(in: shared))
    }

    private func scratchSuite(_ role: String) throws -> UserDefaults {
        let suiteName = "lead-track-privacy-tests-\(role)-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
