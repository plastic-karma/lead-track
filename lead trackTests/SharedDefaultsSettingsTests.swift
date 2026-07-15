import Foundation
import Testing
@testable import lead_track

/// The two shared-defaults stores: the watch snapshot cache and the
/// countdown completion-alert toggles.
struct SharedDefaultsSettingsTests {
    private func scratchSuite(_ name: String = #function) throws -> UserDefaults {
        let suiteName = "lead-track-tests-\(name)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    // MARK: - WatchSnapshotCache

    @Test
    func missingCacheLoadsEmpty() throws {
        let defaults = try scratchSuite()
        #expect(WatchSnapshotCache.load(from: defaults) == .empty)
    }

    @Test
    func corruptCacheFallsBackToEmpty() throws {
        let defaults = try scratchSuite()
        defaults.set(Data("not json".utf8), forKey: "cachedWatchSnapshot")
        #expect(WatchSnapshotCache.load(from: defaults) == .empty)
    }

    @Test
    func snapshotRoundTripsThroughTheCache() throws {
        let defaults = try scratchSuite()
        let snapshot = WatchSnapshot(
            metrics: [
                WatchMetricSnapshot(
                    id: UUID(),
                    name: "Reading",
                    measurementType: .duration,
                    unit: nil,
                    icon: "book",
                    colorName: nil,
                    todayTotal: 120
                )
            ],
            day: Calendar.current.startOfDay(for: .now),
            builtAt: Date(timeIntervalSince1970: 1_750_000_000)
        )

        WatchSnapshotCache.save(snapshot, to: defaults)

        #expect(WatchSnapshotCache.load(from: defaults) == snapshot)
    }

    // MARK: - CompletionAlertSettings

    @Test
    func alertTogglesDefaultToOn() throws {
        let defaults = try scratchSuite()
        #expect(CompletionAlertSettings.enabled(
            CompletionAlertSettings.soundKey, in: defaults
        ))
        #expect(CompletionAlertSettings.enabled(
            CompletionAlertSettings.hapticKey, in: defaults
        ))
    }

    @Test
    func alertTogglesRoundTrip() throws {
        let defaults = try scratchSuite()
        let key = CompletionAlertSettings.soundKey

        defaults.set(false, forKey: key)
        #expect(!CompletionAlertSettings.enabled(key, in: defaults))

        defaults.set(true, forKey: key)
        #expect(CompletionAlertSettings.enabled(key, in: defaults))

        defaults.removeObject(forKey: key)
        #expect(CompletionAlertSettings.enabled(key, in: defaults))
    }
}
