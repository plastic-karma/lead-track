import Foundation

/// Apply only changes made by the app to the acknowledged vault representation.
/// Unknown properties, Markdown whitespace and Obsidian renames are not app edits.
enum VaultLocalChanges {
    static func overlay(snapshot: VaultGraph, base: VaultGraph, projection: VaultGraph) -> VaultGraph {
        var result = base
        result.records = [:]
        for (id, current) in snapshot.records {
            guard var record = base.records[id], let previous = projection.records[id] else {
                result.records[id] = current
                continue
            }
            for key in Set(previous.fields.keys).union(current.fields.keys)
                where previous.fields[key] != current.fields[key]
            {
                record.fields[key] = current.fields[key]
            }
            if current.body != previous.body { record.body = current.body }
            result.records[id] = record
        }
        applyAttachments(snapshot: snapshot, base: base, projection: projection, result: &result)
        return result
    }

    private static func applyAttachments(
        snapshot: VaultGraph,
        base: VaultGraph,
        projection: VaultGraph,
        result: inout VaultGraph
    ) {
        var obsolete = Set<String>()
        for (id, original) in base.records {
            guard let field = VaultAttachmentLinks.ownerField(original.kind),
                  let path = try? VaultAttachmentLinks.path(original.fields[field], graph: base) else { continue }
            if snapshot.records[id] == nil { obsolete.insert(path) }
        }
        for (id, current) in snapshot.records {
            guard let field = VaultAttachmentLinks.ownerField(current.kind) else { continue }
            let before = attachment(projection.records[id]?.fields[field], graph: projection)
            let after = attachment(current.fields[field], graph: snapshot)
            guard before?.data != after?.data || projection.records[id] == nil else { continue }
            if let original = base.records[id],
               let path = try? VaultAttachmentLinks.path(original.fields[field], graph: base)
            {
                obsolete.insert(path)
            }
            guard let after else {
                result.records[id]?.fields[field] = current.fields[field]
                continue
            }
            let path = availablePath(after.path, data: after.data, attachments: result.attachments)
            result.attachments[path] = after.data
            let previousLink = base.records[id]?.fields[field] ?? current.fields[field]
            result.records[id]?.fields[field] = attachmentLink(path, preserving: previousLink)
        }
        // Invalid or ambiguous user metadata must never authorize deletion.
        guard let referenced = try? VaultAttachmentLinks.referenced(in: result) else { return }
        for path in obsolete where !referenced.contains(path) {
            result.attachments[path] = nil
        }
    }

    private static func attachmentLink(_ path: String, preserving value: VaultValue?) -> VaultValue {
        guard case let .string(link) = value, link.hasPrefix("[["), link.hasSuffix("]]"),
              let divider = link.firstIndex(of: "|") else { return .string("[[\(path)]]") }
        return .string("[[\(path)\(link[divider...])")
    }

    private static func attachment(_ value: VaultValue?, graph: VaultGraph) -> (path: String, data: Data)? {
        guard let path = try? VaultAttachmentLinks.path(value, graph: graph),
              let data = graph.attachments[path] else { return nil }
        return (path, data)
    }

    private static func availablePath(_ canonical: String, data: Data, attachments: [String: Data]) -> String {
        guard let existing = attachments[canonical], existing != data else { return canonical }
        let stem = (canonical as NSString).deletingPathExtension
        let ext = (canonical as NSString).pathExtension
        var suffix = 2
        var candidate = "\(stem)-\(suffix).\(ext)"
        while let existing = attachments[candidate], existing != data {
            suffix += 1
            candidate = "\(stem)-\(suffix).\(ext)"
        }
        return candidate
    }
}
