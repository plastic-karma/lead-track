import Foundation

/// Persists the last received snapshot so the watch UI has data immediately
/// on launch, before the phone responds.
enum WatchSnapshotCache {
    private static let key = "cachedWatchSnapshot"

    static func load() -> WatchSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data)
        else { return .empty }
        return snapshot
    }

    static func save(_ snapshot: WatchSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
