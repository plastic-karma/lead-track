import Foundation

/// Persists the last received snapshot so the watch UI has data immediately
/// on launch, before the phone responds. Stored in the shared app group so
/// the watch widget extension can render the same state.
enum WatchSnapshotCache {
    private static let key = "cachedWatchSnapshot"

    static func load() -> WatchSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func save(_ snapshot: WatchSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }
}
