import Foundation

/// Encodes watch-sync payloads into the property-list dictionaries that
/// WatchConnectivity transports, and decodes them back. Failures return nil
/// and log — never an empty payload that would be "successfully" pushed and
/// silently wipe or freeze the other side.
enum WatchSyncCodec {
    private static let snapshotKey = "snapshot"
    private static let actionKey = "action"
    private static let refreshKey = "refresh"

    static func context(for snapshot: WatchSnapshot) -> [String: Any]? {
        do {
            return try [snapshotKey: JSONEncoder().encode(snapshot)]
        } catch {
            SyncLog.error("Snapshot encode failed: \(error)")
            return nil
        }
    }

    static func snapshot(from context: [String: Any]) -> WatchSnapshot? {
        guard let data = context[snapshotKey] as? Data else { return nil }
        do {
            return try JSONDecoder().decode(WatchSnapshot.self, from: data)
        } catch {
            SyncLog.error("Snapshot decode failed: \(error)")
            return nil
        }
    }

    static func message(for action: WatchAction) -> [String: Any]? {
        do {
            return try [actionKey: JSONEncoder().encode(action)]
        } catch {
            SyncLog.error("Action encode failed: \(error)")
            return nil
        }
    }

    static func action(from message: [String: Any]) -> WatchAction? {
        guard let data = message[actionKey] as? Data else { return nil }
        do {
            return try JSONDecoder().decode(WatchAction.self, from: data)
        } catch {
            // Version skew: an older phone can receive a Kind it doesn't
            // know. The recording is lost either way; the trace is what
            // makes that diagnosable.
            SyncLog.error("Action decode failed: \(error)")
            return nil
        }
    }

    static var refreshRequest: [String: Any] {
        [refreshKey: true]
    }

    static func isRefreshRequest(_ message: [String: Any]) -> Bool {
        message[refreshKey] as? Bool == true
    }
}
