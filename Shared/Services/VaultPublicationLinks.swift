import Foundation

/// Resolve generated identity links against the names Obsidian currently uses.
enum VaultPublicationLinks {
    static func rewrite(_ graph: VaultGraph, folder: String) throws -> VaultGraph {
        guard VaultModelLinks.safePath(folder) else { throw VaultError.invalid("Invalid vault folder") }
        var result = graph
        result.attachmentRoot = folder
        let names = filenameCounts(graph)
        for (id, original) in graph.records {
            var record = original
            for key in relationshipKeys(record.kind) {
                if let value = record.fields[key] {
                    record.fields[key] = try rewrite(value, graph: graph, folder: folder, names: names)
                }
            }
            result.records[id] = record
        }
        return result
    }

    private static func rewrite(
        _ value: VaultValue,
        graph: VaultGraph,
        folder: String,
        names: [String: Int]
    ) throws -> VaultValue {
        if case let .array(values) = value {
            return try .array(values.map { try rewrite($0, graph: graph, folder: folder, names: names) })
        }
        guard case let .string(link) = value,
              let target = try? VaultModelLinks.target(value),
              let id = UUID(uuidString: target), let record = graph.records[id] else { return value }
        let canonical = "\(record.kind.folder)/\(id.uuidString.lowercased()).md"
        if record.path == canonical, names["\(id.uuidString.lowercased()).md"] == 1 { return value }
        let destination = "\(folder)/\(record.path)"
        guard VaultModelLinks.safePath(record.path), record.path.hasSuffix(".md"),
              !["#", "|", "[[", "]]"].contains(where: destination.contains)
        else {
            throw VaultError.invalid("Invalid relationship destination")
        }
        let inner = link.dropFirst(2).dropLast(2)
        let label = inner.firstIndex(of: "|").map { String(inner[$0...]) } ?? ""
        return .string("[[\(destination)\(label)]]")
    }

    private static func filenameCounts(_ graph: VaultGraph) -> [String: Int] {
        var counts: [String: Int] = [:]
        for record in graph.records.values {
            if let name = record.path.split(separator: "/").last {
                counts[name.lowercased(), default: 0] += 1
            }
        }
        return counts
    }

    private static func relationshipKeys(_ kind: VaultKind) -> [String] {
        switch kind {
        case .aspiration: ["metrics", "projects"]
        case .metric: []
        case .project: ["metric"]
        case .session: ["metric", "project"]
        case .principle, .checkIn: ["aspiration"]
        case .intention: ["aspiration", "metric", "principle", "predecessor"]
        case .moment: ["aspiration", "metric", "project", "principle"]
        case .photo: ["moment"]
        }
    }
}
