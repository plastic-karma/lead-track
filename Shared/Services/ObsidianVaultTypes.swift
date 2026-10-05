import Foundation

/// Identities, not note names, join app records across devices and vault renames.
nonisolated enum VaultKind: String, Codable, CaseIterable {
    case aspiration, metric, project, session, principle, intention, checkIn, moment, photo

    var folder: String {
        switch self {
        case .aspiration: "Aspirations"
        case .metric: "Metrics"
        case .project: "Projects"
        case .session: "Data"
        case .principle: "Principles"
        case .intention: "Intentions"
        case .checkIn: "CheckIns"
        case .moment: "Moments"
        case .photo: "Photos"
        }
    }
}

indirect nonisolated enum VaultValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case array([VaultValue])
    case null
    /// Unrecognized YAML stays in the vault, but cannot populate a typed app field.
    case raw(String)
}

nonisolated struct VaultRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var kind: VaultKind
    var fields: [String: VaultValue]
    var body: String
    var path: String
    var propertyOrder: [String]

    init(
        id: UUID,
        kind: VaultKind,
        fields: [String: VaultValue] = [:],
        body: String = "",
        path: String? = nil,
        propertyOrder: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.fields = fields
        self.body = body
        self.path = path ?? "\(kind.folder)/\(id.uuidString.lowercased()).md"
        self.propertyOrder = propertyOrder
    }

    var label: String {
        if case let .string(title) = fields["title"] { return title }
        if case let .string(name) = fields["name"] { return name }
        return "\(kind.rawValue) \(id.uuidString.prefix(8))"
    }

    /// Property order preserves YAML anchors, but reordering properties alone is not an app edit.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id && lhs.kind == rhs.kind && lhs.fields == rhs.fields
            && lhs.body == rhs.body && lhs.path == rhs.path
    }
}

nonisolated struct VaultGraph: Codable, Equatable {
    var records: [UUID: VaultRecord] = [:]
    var attachments: [String: Data] = [:]
    var attachmentRoot: String = ""
}

nonisolated struct VaultSessionOwnershipIssue: Equatable {
    let sessionID: UUID?
    let projectID: UUID?
    let metricBacklinkIDs: [UUID]
    let projectBacklinkIDs: [UUID]

    var errorDescription: String {
        let metrics = metricBacklinkIDs.lazy.map(\.uuidString).joined(separator: ", ")
        let projects = projectBacklinkIDs.lazy.map(\.uuidString).joined(separator: ", ")
        return "Session requires a metric. Session: \(sessionID?.uuidString ?? "none"); "
            + "linked project: \(projectID?.uuidString ?? "none"); "
            + "metric backlinks: [\(metrics)]; project backlinks: [\(projects)]."
    }
}

nonisolated enum VaultError: Error, LocalizedError {
    case invalid(String)
    case conflict(String)
    case remote(String)
    case sessionWithoutMetric(VaultSessionOwnershipIssue)

    var errorDescription: String? {
        switch self {
        case let .invalid(message), let .conflict(message), let .remote(message): message
        case let .sessionWithoutMetric(issue): issue.errorDescription
        }
    }
}

nonisolated struct VaultRemoteFile: Codable, Equatable {
    var sha: String
    var data: Data
}

nonisolated struct VaultRemoteSnapshot {
    var headSHA: String
    var treeSHA: String
    var files: [String: VaultRemoteFile]
}

nonisolated struct VaultFileChange {
    var path: String
    var data: Data?
}

protocol VaultRemote: Sendable {
    func fetch(cached: [String: VaultRemoteFile]) async throws -> VaultRemoteSnapshot
    func commit(changes: [VaultFileChange], onto snapshot: VaultRemoteSnapshot) async throws -> String
}
