import Foundation

/// Encodes watch-sync payloads into the property-list dictionaries that
/// WatchConnectivity transports, and decodes them back.
enum WatchSyncCodec {
    private static let snapshotKey = "snapshot"
    private static let actionKey = "action"
    private static let refreshKey = "refresh"

    static func context(for snapshot: WatchSnapshot) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(snapshot) else { return [:] }
        return [snapshotKey: data]
    }

    static func snapshot(from context: [String: Any]) -> WatchSnapshot? {
        guard let data = context[snapshotKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchSnapshot.self, from: data)
    }

    static func message(for action: WatchAction) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(action) else { return [:] }
        return [actionKey: data]
    }

    static func action(from message: [String: Any]) -> WatchAction? {
        guard let data = message[actionKey] as? Data else { return nil }
        return try? JSONDecoder().decode(WatchAction.self, from: data)
    }

    static var refreshRequest: [String: Any] {
        [refreshKey: true]
    }

    static func isRefreshRequest(_ message: [String: Any]) -> Bool {
        message[refreshKey] as? Bool == true
    }
}
