import Foundation

/// Raw values contain everything after the property's colon, including continuation lines.
nonisolated enum VaultFrontmatter {
    static func decode(_ text: String) throws -> [String: VaultValue] {
        try decodeOrdered(text).fields
    }

    static func decodeOrdered(_ text: String) throws -> (fields: [String: VaultValue], propertyOrder: [String]) {
        guard text.utf8.count <= 1_048_576 else {
            throw VaultError.invalid("Managed note frontmatter exceeds the 1 MiB safety limit.")
        }
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var fields: [String: VaultValue] = [:]
        var propertyOrder: [String] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if ignorable(line) { index += 1; continue }
            guard !line.hasPrefix(" "), !line.hasPrefix("\t"),
                  let colon = keyColon(line)
            else {
                throw VaultError.invalid("Expected a top-level YAML property.")
            }
            let key = try propertyKey(String(line[..<colon]))
            guard fields[key] == nil else { throw VaultError.invalid("Duplicate YAML property: \(key).") }
            var raw = String(line[line.index(after: colon)...])
            if index < lines.count - 1 { raw += "\n" }
            index += 1
            while index < lines.count, continuation(lines[index]) {
                raw += lines[index]
                if index < lines.count - 1 { raw += "\n" }
                index += 1
            }
            fields[key] = try node(raw)
            propertyOrder.append(key)
        }
        return (fields, propertyOrder)
    }

    static func encode(_ fields: [String: VaultValue], propertyOrder: [String] = []) throws -> String {
        try orderedKeys(fields, propertyOrder: propertyOrder).map { key in
            guard !key.isEmpty, !key.contains("\n"), !key.contains("\r") else {
                throw VaultError.invalid("Invalid YAML property name.")
            }
            let encodedKey = key.range(of: "^[A-Za-z_][A-Za-z0-9_-]*$", options: .regularExpression) != nil
                ? key : quote(key)
            guard let value = fields[key] else { return "" }
            if case let .raw(raw) = value {
                return encodedKey + ":" + raw + (raw.hasSuffix("\n") ? "" : "\n")
            }
            return try encodedKey + ": " + scalar(value) + "\n"
        }.joined()
    }

    private static func orderedKeys(_ fields: [String: VaultValue], propertyOrder: [String]) throws -> [String] {
        let recorded = Set(propertyOrder)
        guard recorded.count == propertyOrder.count else {
            throw VaultError.invalid("Duplicate YAML property order entries.")
        }
        for (key, value) in fields {
            if case .raw = value, !recorded.contains(key) {
                throw VaultError.invalid("Original property order is required to preserve raw YAML safely.")
            }
        }
        return propertyOrder.filter { fields[$0] != nil } + fields.keys.filter { !recorded.contains($0) }.sorted()
    }

    static func quote(_ text: String) -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            case _ where scalar.value < 32 || scalar.value == 127:
                result += String(format: "\\u%04X", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    private static func scalar(_ value: VaultValue) throws -> String {
        switch value {
        case let .string(text): return quote(text)
        case let .number(number):
            guard number.isFinite else { throw VaultError.invalid("YAML numbers must be finite.") }
            let text = String(number)
            return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
        case let .bool(value): return value ? "true" : "false"
        case .null: return "null"
        case let .array(values): return try "[" + (values.map(scalar)).joined(separator: ", ") + "]"
        case .raw: throw VaultError.invalid("Raw YAML is only supported as a top-level property.")
        }
    }

    private static func node(_ raw: String) throws -> VaultValue {
        var lines = raw.components(separatedBy: "\n")
        if lines.last == "" { lines.removeLast() }
        let first = VaultFrontmatterScalar.stripComment(lines.first ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if first.hasPrefix("|") || first.hasPrefix(">") {
            let blockLines = lines.dropFirst().filter { !$0.hasPrefix("#") }
            return try VaultFrontmatterBlock.decode(header: first, lines: blockLines)
        }
        let continuation = lines.dropFirst().filter { !ignorable($0) }
        if first.isEmpty, !continuation.isEmpty {
            return try blockSequence(Array(continuation), raw: raw)
        }
        if first.hasPrefix("["), !continuation.isEmpty {
            let flow = ([lines.first ?? ""] + continuation)
                .map(VaultFrontmatterScalar.stripComment).joined(separator: "\n")
            let value = try VaultFrontmatterScalar.decode(flow)
            if case .raw = value { return .raw(raw) }
            return value
        }
        if !continuation.isEmpty { return .raw(raw) }
        let value = try VaultFrontmatterScalar.decode(lines.first ?? "")
        if case .raw = value { return .raw(raw) }
        return value
    }

    private static func blockSequence(_ lines: [String], raw: String) throws -> VaultValue {
        var values: [VaultValue] = []
        let indentation = lines.first?.prefix(while: { $0 == " " }).count ?? 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard line.prefix(while: { $0 == " " }).count == indentation,
                  trimmed == "-" || trimmed.hasPrefix("- ") else { return .raw(raw) }
            let value = try VaultFrontmatterScalar.decode(String(trimmed.dropFirst()))
            if case .raw = value { return .raw(raw) }
            values.append(value)
        }
        return .array(values)
    }

    private static func propertyKey(_ text: String) throws -> String {
        let key = text.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { throw VaultError.invalid("Empty YAML property name.") }
        if key.hasPrefix("\"") || key.hasPrefix("'") {
            guard case let .string(value) = try VaultFrontmatterScalar.decode(key) else {
                throw VaultError.invalid("Invalid YAML property name.")
            }
            return value
        }
        return key
    }

    private static func keyColon(_ line: String) -> String.Index? {
        var quote: Character?
        var escaped = false
        for index in line.indices {
            let character = line[index]
            if escaped { escaped = false; continue }
            if let current = quote {
                if character == "\\", current == "\"" { escaped = true }
                else if character == current { quote = nil }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == ":" {
                let next = line.index(after: index)
                if next == line.endIndex || line[next].isWhitespace { return index }
            }
        }
        return nil
    }

    private static func ignorable(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed.hasPrefix("#")
    }

    private static func continuation(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return ignorable(line) || line.hasPrefix(" ") || line.hasPrefix("\t")
            || line.hasPrefix("- ") || trimmed == "-" || trimmed == "]" || trimmed == "}"
    }
}
