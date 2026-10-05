import Foundation

enum ObsidianVaultCodec {
    private static let reserved = ["leadstone_id", "leadstone_type", "leadstone_version"]

    static func decode(_ files: [String: Data], folder: String = "") throws -> VaultGraph {
        guard folder.isEmpty || VaultModelLinks.safePath(folder)
        else { throw VaultError.invalid("Invalid vault folder") }
        var graph = VaultGraph()
        graph.attachmentRoot = folder
        for (path, data) in files {
            try validatePath(path)
            guard path.lowercased().hasSuffix(".md") else { continue }
            guard let record = try decodeNote(data, path: path) else { continue }
            guard graph.records[record.id] == nil else {
                throw VaultError.invalid("Duplicate LeadStone record ID in \(path).")
            }
            graph.records[record.id] = record
        }
        graph.attachments = files.filter { $0.key.hasPrefix("Attachments/") }
        let referenced = try VaultAttachmentLinks.referenced(in: graph)
        graph.attachments = graph.attachments.filter { referenced.contains($0.key) }
        return graph
    }

    static func encode(_ graph: VaultGraph) throws -> [String: Data] {
        var files: [String: Data] = [:]
        for (id, record) in graph.records {
            guard id == record.id else { throw VaultError.invalid("Record dictionary identity mismatch.") }
            try validatePath(record.path)
            guard record.path.lowercased().hasSuffix(".md"), !record.path.hasPrefix("Attachments/") else {
                throw VaultError.invalid("Managed records must have Markdown note paths.")
            }
            guard files[record.path] == nil else { throw VaultError.invalid("Duplicate managed note path.") }
            let frontmatter = try VaultFrontmatter.encode(properties(record), propertyOrder: record.propertyOrder)
            files[record.path] = Data(("---\n" + frontmatter + "---\n" + record.body).utf8)
        }
        for (path, data) in graph.attachments {
            try validatePath(path)
            guard path.hasPrefix("Attachments/"), files[path] == nil else {
                throw VaultError.invalid("Attachments must have unique paths under Attachments/.")
            }
            files[path] = data
        }
        return files
    }

    static func bases() -> [String: Data] {
        VaultBases.files()
    }

    private static func properties(_ record: VaultRecord) throws -> [String: VaultValue] {
        var fields = record.fields
        guard reserved.allSatisfy({ fields[$0] == nil }) else {
            throw VaultError.invalid("Record fields cannot replace reserved LeadStone properties.")
        }
        if fields["aliases"] == nil {
            let label = fields["title"] ?? fields["name"]
            if case let .string(text) = label, !text.isEmpty { fields["aliases"] = .array([.string(text)]) }
        }
        fields["leadstone_id"] = .string(record.id.uuidString.lowercased())
        fields["leadstone_type"] = .string(record.kind.rawValue)
        fields["leadstone_version"] = .number(1)
        return fields
    }

    private static func decodeNote(_ data: Data, path: String) throws -> VaultRecord? {
        let lossy = String(decoding: data, as: UTF8.self)
        guard let framed = try frame(lossy) else { return nil }
        guard String(data: data, encoding: .utf8) != nil else {
            throw VaultError.invalid("Managed note \(path) is not UTF-8.")
        }
        let decoded = try VaultFrontmatter.decodeOrdered(framed.header)
        var fields = decoded.fields
        guard case let .string(idText) = fields.removeValue(forKey: "leadstone_id"),
              let id = UUID(uuidString: idText),
              case let .string(type) = fields.removeValue(forKey: "leadstone_type"),
              let kind = VaultKind(rawValue: type)
        else {
            throw VaultError.invalid("Invalid LeadStone identity or type in \(path).")
        }
        guard fields.removeValue(forKey: "leadstone_version") == .number(1) else {
            throw VaultError.invalid("Unsupported or missing LeadStone schema version in \(path).")
        }
        guard !path.hasPrefix("Attachments/") else {
            throw VaultError.invalid("Managed notes cannot live under Attachments/.")
        }
        return VaultRecord(
            id: id, kind: kind, fields: fields, body: framed.body, path: path, propertyOrder: decoded.propertyOrder
        )
    }

    private static func frame(_ source: String) throws -> (header: String, body: String)? {
        let text = source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source
        let firstEnd = text.firstIndex(where: \.isNewline) ?? text.endIndex
        let first = text[..<firstEnd].trimmingCharacters(in: .whitespacesAndNewlines)
        guard first == "---" else {
            if looksManaged(String(text.prefix(4096))), first.hasPrefix("---") {
                throw VaultError.invalid("Malformed managed note frontmatter opening delimiter.")
            }
            return nil
        }
        let start = firstEnd == text.endIndex ? firstEnd : text.index(after: firstEnd)
        var lineStart = start
        while lineStart < text.endIndex {
            let lineEnd = text[lineStart...].firstIndex(where: \.isNewline) ?? text.endIndex
            let sourceLine = text[lineStart ..< lineEnd]
            let line = sourceLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if sourceLine.hasPrefix("---") || sourceLine.hasPrefix("..."), line == "---" || line == "..." {
                let header = String(text[start ..< lineStart])
                guard looksManaged(header) else { return nil }
                let bodyStart = lineEnd == text.endIndex ? lineEnd : text.index(after: lineEnd)
                return (header, String(text[bodyStart...]))
            }
            lineStart = lineEnd == text.endIndex ? lineEnd : text.index(after: lineEnd)
        }
        if looksManaged(String(text[start...])) {
            throw VaultError.invalid("Managed note frontmatter has no closing delimiter.")
        }
        return nil
    }

    private static func looksManaged(_ header: String) -> Bool {
        header.range(
            of: "(?m)^[ \\t]*[\\\"']?leadstone_(id|type|version)([\\\"']|[ \\t:]|$)",
            options: .regularExpression
        ) != nil
    }

    private static func validatePath(_ path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty, !path.contains("\\"),
              !path.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              components.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." })
        else {
            throw VaultError.invalid("Unsafe vault file path.")
        }
    }
}
