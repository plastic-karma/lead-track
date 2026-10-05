import Foundation

/// Identifies a model-validation boundary without obscuring the original vault error.
nonisolated struct VaultSyncFailure: LocalizedError {
    enum Stage {
        case localSnapshot
        case syncSnapshot
        case localRecheck
        case localApply

        var description: String {
            switch self {
            case .localSnapshot: "Reading the initial local snapshot"
            case .syncSnapshot: "Validating the merged sync snapshot before publication"
            case .localRecheck: "Rechecking local data after publication"
            case .localApply: "Applying the published sync to local data"
            }
        }
    }

    let stage: Stage
    let underlying: VaultError

    var errorDescription: String? {
        "\(stage.description): \(underlying.localizedDescription)"
    }
}

struct VaultPendingSync: Codable {
    var source: VaultGraph
    var target: VaultGraph
    var transactionID = UUID()
    var projection: VaultGraph
    var files: [String: VaultRemoteFile]
    var published = false
}

struct VaultSyncState: Codable {
    var version = 1
    var destination: String
    var baseline = VaultGraph()
    var projection = VaultGraph()
    var files: [String: VaultRemoteFile] = [:]
    var pending: VaultPendingSync?
    var lastSyncedAt: Date?
}

@MainActor
protocol VaultStatePersistence {
    func load(destination: String) throws -> VaultSyncState
    func save(_ state: VaultSyncState) throws
}

/// A failed read never masquerades as a first sync: that could resurrect deletions.
struct VaultStateFile: VaultStatePersistence {
    let url: URL

    func load(destination: String) throws -> VaultSyncState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return VaultSyncState(destination: destination)
        }
        let state = try JSONDecoder().decode(VaultSyncState.self, from: Data(contentsOf: url))
        guard state.version == 1 else {
            throw VaultError.invalid("This sync journal was written by a newer LeadStone version.")
        }
        guard state.destination == destination else {
            throw VaultError.invalid("This sync journal belongs to a different vault destination.")
        }
        return state
    }

    func save(_ state: VaultSyncState) throws {
        let directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]
        )
        let data = try JSONEncoder().encode(state)
        #if os(iOS)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: url, options: .atomic)
        #endif
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    static func forDestination(_ identity: String, in directory: URL) -> Self {
        let encoded = Data(identity.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        var directory = directory
        var start = encoded.startIndex
        while start < encoded.endIndex {
            let end = encoded.index(start, offsetBy: 120, limitedBy: encoded.endIndex) ?? encoded.endIndex
            directory.append(path: String(encoded[start ..< end]))
            start = end
        }
        return Self(url: directory.appending(path: "state.json"))
    }
}

struct VaultApplyTransaction: Codable, Equatable {
    var id: UUID
    var destination: String
}

@MainActor
protocol VaultLocalStore {
    func snapshot() throws -> VaultGraph
    func appliedTransaction(destination: String) throws -> UUID?
    func apply(_ graph: VaultGraph, expecting expected: VaultGraph, transaction: VaultApplyTransaction) throws
}

struct VaultSyncOutcome {
    var conflicts: [VaultConflict] = []
    var needsSync = false
    var date: Date?
}
