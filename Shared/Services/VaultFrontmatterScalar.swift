import Foundation

/// The scalar subset emitted by Obsidian's Properties editor, without coercing YAML objects.
nonisolated enum VaultFrontmatterScalar {
    static func decode(_ source: String) throws -> VaultValue {
        try decode(source, depth: 0)
    }

    private static func decode(_ source: String, depth: Int) throws -> VaultValue {
        guard depth < 32 else { throw VaultError.invalid("YAML sequences are nested too deeply.") }
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("[["), trimmed.hasSuffix("]]"), !trimmed.contains("\n") {
            return .string(trimmed)
        }
        let text = stripComment(trimmed).trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("["), text.hasSuffix("]") { return try sequence(text, depth: depth) }
        if text.hasPrefix("\"") { return try .string(doubleQuoted(text)) }
        if text.hasPrefix("'") { return try .string(singleQuoted(text)) }
        if unsupported(text) { return .raw(source) }
        let plain = stripComment(text).trimmingCharacters(in: .whitespaces)
        switch plain.lowercased() {
        case "", "null", "~": return .null
        case "true": return .bool(true)
        case "false": return .bool(false)
        default: break
        }
        if let number = Double(plain), number.isFinite { return .number(number) }
        if [".nan", ".inf", "+.inf", "-.inf"].contains(plain.lowercased()) {
            return .raw(source)
        }
        return .string(plain)
    }

    static func stripComment(_ text: String) -> String {
        var previous: Character?
        var quote: Character?
        var escaped = false
        for index in text.indices {
            let character = text[index]
            defer { previous = character }
            if escaped { escaped = false; continue }
            if let current = quote {
                if character == "\\", current == "\"" { escaped = true }
                else if character == current { quote = nil }
                continue
            }
            if character == "\"" || character == "'",
               previous == nil || previous?.isWhitespace == true || previous == "[" || previous == ","
            {
                quote = character
            }
            if character == "#", previous == nil || previous?.isWhitespace == true {
                return String(text[..<index])
            }
        }
        return text
    }

    private static func unsupported(_ text: String) -> Bool {
        guard let first = text.first else { return false }
        if "{[&*!|>@`%".contains(first) { return true }
        return text.contains(": ") || text.contains("\n")
    }

    private static func singleQuoted(_ text: String) throws -> String {
        var index = text.index(after: text.startIndex)
        var result = ""
        while index < text.endIndex {
            let character = text[index]
            index = text.index(after: index)
            if character != "'" { result.append(character); continue }
            if index < text.endIndex, text[index] == "'" {
                result.append("'")
                index = text.index(after: index)
            } else {
                try validateRemainder(String(text[index...]))
                return result
            }
        }
        throw VaultError.invalid("Unclosed single-quoted YAML property.")
    }

    private static func doubleQuoted(_ text: String) throws -> String {
        var index = text.index(after: text.startIndex)
        var result = ""
        while index < text.endIndex {
            let character = text[index]
            index = text.index(after: index)
            if character == "\"" {
                try validateRemainder(String(text[index...]))
                return result
            }
            if character == "\\" {
                result += try escape(text, index: &index)
            } else {
                result.append(character)
            }
        }
        throw VaultError.invalid("Unclosed double-quoted YAML property.")
    }

    private static func escape(_ text: String, index: inout String.Index) throws -> String {
        guard index < text.endIndex else { throw VaultError.invalid("Incomplete YAML escape.") }
        let character = text[index]
        index = text.index(after: index)
        let escapes: [Character: String] = [
            "0": "\0", "a": "\u{7}", "b": "\u{8}", "t": "\t", "n": "\n", "v": "\u{B}",
            "f": "\u{C}", "r": "\r", "e": "\u{1B}", " ": " ", "\"": "\"", "/": "/", "\\": "\\",
            "N": "\u{85}", "_": "\u{A0}", "L": "\u{2028}", "P": "\u{2029}"
        ]
        if let value = escapes[character] { return value }
        let count: Int
        switch character {
        case "x": count = 2
        case "u": count = 4
        case "U": count = 8
        default: throw VaultError.invalid("Invalid YAML string escape.")
        }
        guard let end = text.index(index, offsetBy: count, limitedBy: text.endIndex),
              let value = UInt32(text[index ..< end], radix: 16), let scalar = UnicodeScalar(value)
        else { throw VaultError.invalid("Invalid YAML Unicode escape.") }
        index = end
        return String(scalar)
    }

    private static func validateRemainder(_ text: String) throws {
        let remainder = text.trimmingCharacters(in: .whitespaces)
        guard remainder.isEmpty || remainder.hasPrefix("#") else {
            throw VaultError.invalid("Unexpected text after a quoted YAML property.")
        }
    }

    private static func sequence(_ text: String, depth: Int) throws -> VaultValue {
        let inner = String(text.dropFirst().dropLast())
        let parts = try splitFlow(inner)
        var values: [VaultValue] = []
        for (index, part) in parts.enumerated() {
            if part.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard index == parts.count - 1 else { throw VaultError.invalid("Empty YAML sequence entry.") }
                continue
            }
            let value = try decode(part, depth: depth + 1)
            if case .raw = value { return .raw(text) }
            values.append(value)
        }
        return .array(values)
    }

    private static func splitFlow(_ text: String) throws -> [String] {
        var state = VaultFlowState()
        var start = text.startIndex
        var parts: [String] = []
        for index in text.indices where try state.consume(text[index]) {
            parts.append(String(text[start ..< index]))
            start = text.index(after: index)
        }
        guard state.isClosed else { throw VaultError.invalid("Unclosed YAML flow property.") }
        parts.append(String(text[start...]))
        return parts
    }
}

private nonisolated struct VaultFlowState {
    private var quote: Character?
    private var escaped = false
    private var depth = 0

    var isClosed: Bool {
        quote == nil && depth == 0
    }

    mutating func consume(_ character: Character) throws -> Bool {
        if quote != nil || escaped {
            consumeQuoted(character)
            return false
        }
        switch character {
        case "\"", "'": quote = character
        case "[", "{": depth += 1
        case "]", "}": depth -= 1
        default: break
        }
        guard depth >= 0 else { throw VaultError.invalid("Unbalanced YAML flow property.") }
        return character == "," && depth == 0
    }

    private mutating func consumeQuoted(_ character: Character) {
        if escaped {
            escaped = false
        } else if character == "\\", quote == "\"" {
            escaped = true
        } else if character == quote {
            quote = nil
        }
    }
}
