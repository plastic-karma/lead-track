import Foundation

enum VaultConflictContent: Equatable {
    case record(VaultRecord)
    case value(VaultValue)
    case text(String)
    case attachment(Data)

    var summary: String {
        switch self {
        case let .record(record): Self.recordSummary(record)
        case let .text(text): text
        case let .attachment(data): "Attachment (\(data.count.formatted()) bytes)"
        case let .value(value): value.summary
        }
    }

    private static func recordSummary(_ record: VaultRecord) -> String {
        let properties = record.fields.keys.sorted().map { "\($0): \(record.fields[$0]?.summary ?? "")" }
        return ([record.label, record.path] + properties + [record.body]).joined(separator: "\n")
    }
}

extension VaultValue {
    var summary: String {
        switch self {
        case let .string(value), let .raw(value): value
        case let .number(value): value.formatted()
        case let .bool(value): value ? "true" : "false"
        case let .array(values): values.map(\.summary).joined(separator: ", ")
        case .null: "Empty"
        }
    }
}

struct VaultConflict: Equatable, Identifiable {
    var id: String
    var label: String
    var local: VaultConflictContent?
    var remote: VaultConflictContent?
}

struct VaultResolution: Equatable {
    enum Choice: Equatable { case local, remote }
    var conflict: VaultConflict
    var choice: Choice
}

struct VaultMergeResult {
    var graph: VaultGraph
    var conflicts: [VaultConflict]
}

/// No clocks or last-writer-wins: a common ancestor distinguishes edits from absence.
struct VaultMerge {
    var resolutions: [String: VaultResolution] = [:]
    private(set) var conflicts: [VaultConflict] = []

    mutating func merge(base: VaultGraph, local: VaultGraph, remote: VaultGraph) throws -> VaultMergeResult {
        var result = VaultGraph(attachmentRoot: remote.attachmentRoot)
        let identities = Set(base.records.keys).union(local.records.keys).union(remote.records.keys)
        for id in identities.sorted(by: { $0.uuidString < $1.uuidString }) {
            result.records[id] = try record(base.records[id], local.records[id], remote.records[id])
        }
        let paths = Set(base.attachments.keys).union(local.attachments.keys).union(remote.attachments.keys)
        for path in paths.sorted() {
            result.attachments[path] = choose(
                base: base.attachments[path], local: local.attachments[path], remote: remote.attachments[path],
                conflict: { VaultConflict(id: "attachment:\(path)", label: path, local: $0, remote: $1) },
                content: VaultConflictContent.attachment
            )
        }
        return VaultMergeResult(graph: result, conflicts: conflicts)
    }

    private mutating func record(
        _ base: VaultRecord?, _ local: VaultRecord?, _ remote: VaultRecord?
    ) throws -> VaultRecord? {
        guard let local, let remote else {
            return choose(base: base, local: local, remote: remote, conflict: { left, right in
                let item = local ?? remote ?? base
                return VaultConflict(
                    id: "record:\(item?.id.uuidString ?? "")", label: item?.label ?? "Deleted record",
                    local: left, remote: right
                )
            }, content: VaultConflictContent.record)
        }
        guard local.kind == remote.kind, base == nil || base?.kind == local.kind else {
            throw VaultError.invalid("A note changed type without changing its identity: \(remote.path).")
        }
        var result = remote
        let keys = Set(base?.fields.keys ?? [:].keys).union(local.fields.keys).union(remote.fields.keys)
        for key in keys.sorted() {
            result.fields[key] = choose(
                base: base?.fields[key], local: local.fields[key], remote: remote.fields[key],
                conflict: { Self.fieldConflict(local, key, $0, $1) }, content: VaultConflictContent.value
            )
        }
        result.body = choose(
            base: base?.body, local: local.body, remote: remote.body,
            conflict: { Self.fieldConflict(local, "description", $0, $1) }, content: VaultConflictContent.text
        ) ?? ""
        result.path = choose(
            base: base?.path, local: local.path, remote: remote.path,
            conflict: { Self.fieldConflict(local, "file path", $0, $1) }, content: VaultConflictContent.text
        ) ?? remote.path
        return result
    }

    private static func fieldConflict(
        _ record: VaultRecord, _ field: String, _ local: VaultConflictContent?, _ remote: VaultConflictContent?
    ) -> VaultConflict {
        VaultConflict(
            id: "\(record.id.uuidString):\(field)", label: "\(record.label) — \(field)", local: local, remote: remote
        )
    }

    private mutating func choose<Value: Equatable>(
        base: Value?, local: Value?, remote: Value?,
        conflict: (VaultConflictContent?, VaultConflictContent?) -> VaultConflict,
        content: (Value) -> VaultConflictContent
    ) -> Value? {
        if local == remote { return local }
        if local == base { return remote }
        if remote == base { return local }
        let item = conflict(local.map(content), remote.map(content))
        if let resolution = resolutions[item.id], resolution.conflict == item {
            return resolution.choice == .local ? local : remote
        }
        conflicts.append(item)
        return local
    }
}
