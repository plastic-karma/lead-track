import Foundation

nonisolated enum VaultFrontmatterBlock {
    static func decode(header: String, lines: [String]) throws -> VaultValue {
        let modifiers = String(header.dropFirst())
        guard validModifiers(modifiers) else { throw VaultError.invalid("Invalid YAML block scalar header.") }
        let normalized = lines.map { $0.hasSuffix("\r") ? String($0.dropLast()) : $0 }
        let contentLines = normalized.filter { !$0.allSatisfy { $0 == " " } }
        let explicit = modifiers.first(where: { $0.isNumber }).flatMap { Int(String($0)) }
        let indentation = explicit ?? contentLines.first?.prefix(while: { $0 == " " }).count
            ?? normalized.map { $0.prefix(while: { $0 == " " }).count }.max() ?? 0
        guard contentLines.isEmpty || indentation > 0 else {
            throw VaultError.invalid("YAML block text must be indented.")
        }
        let content = try unindent(normalized, indentation: indentation, explicit: explicit != nil)
        var result = header.hasPrefix(">") ? folded(content) : content.map { $0 + "\n" }.joined()
        if !modifiers.contains("+") {
            while result.hasSuffix("\n") {
                result.removeLast()
            }
            if !modifiers.contains("-"), !result.isEmpty { result += "\n" }
        }
        return .string(result)
    }

    private static func validModifiers(_ modifiers: String) -> Bool {
        let digits = modifiers.filter { "123456789".contains($0) }
        let chomps = modifiers.filter { $0 == "+" || $0 == "-" }
        return digits.count <= 1 && chomps.count <= 1 && digits.count + chomps.count == modifiers.count
    }

    private static func unindent(_ lines: [String], indentation: Int, explicit: Bool) throws -> [String] {
        var leading = true
        return try lines.map { line in
            let spaces = line.prefix(while: { $0 == " " }).count
            let blank = spaces == line.count
            if leading, blank, !explicit, spaces > indentation {
                throw VaultError.invalid("Leading YAML blank line exceeds block indentation.")
            }
            if !blank {
                leading = false
                guard spaces >= indentation else {
                    throw VaultError.invalid("Inconsistent YAML block indentation.")
                }
            }
            return String(line.dropFirst(min(spaces, indentation)))
        }
    }

    private static func folded(_ lines: [String]) -> String {
        var result = ""
        var previous: String?
        var blanks = 0
        for line in lines {
            if line.isEmpty { blanks += 1; continue }
            if let previous {
                let indented = moreIndented(previous) || moreIndented(line)
                let breaks = blanks + (indented ? 1 : 0)
                result += breaks == 0 ? " " : String(repeating: "\n", count: breaks)
            } else {
                result += String(repeating: "\n", count: blanks)
            }
            result += line
            previous = line
            blanks = 0
        }
        return result + String(repeating: "\n", count: blanks + (previous == nil ? 0 : 1))
    }

    private static func moreIndented(_ line: String) -> Bool {
        line.hasPrefix(" ") || line.hasPrefix("\t")
    }
}
