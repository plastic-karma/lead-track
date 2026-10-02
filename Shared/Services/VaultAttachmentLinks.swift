import Foundation

/// Resolve only assets from the selected vault subtree, never arbitrary suffix matches.
enum VaultAttachmentLinks {
    private static let markdownTargets = [
        #"!?\[[^\]\n]*\]\(\s*(?:<([^>\n]+)>|([^\s)]+))(?:\s+\"[^\"]*\")?\s*\)"#,
        #"(?m)^\s{0,3}\[[^\]\n]+\]:\s*(?:<([^>\n]+)>|([^\s]+))"#
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    static func resolve(_ target: String, paths: Set<String>, folder: String) throws -> String {
        guard VaultModelLinks.safePath(target), !target.contains("#"), !target.contains("|") else {
            throw VaultError.invalid("Unsafe attachment reference \(target)")
        }
        var matches = Set<String>()
        if target.hasPrefix("Attachments/"), paths.contains(target) { matches.insert(target) }
        if !folder.isEmpty, target.hasPrefix(folder + "/Attachments/") {
            let relative = String(target.dropFirst(folder.count + 1))
            if paths.contains(relative) { matches.insert(relative) }
        }
        if !target.contains("/") {
            matches.formUnion(paths.filter { $0.split(separator: "/").last.map(String.init) == target })
        }
        guard matches.count == 1, let path = matches.first,
              path.hasPrefix("Attachments/"), VaultModelLinks.safePath(path)
        else {
            throw VaultError.invalid("Missing or ambiguous attachment \(target)")
        }
        return path
    }

    static func path(_ value: VaultValue?, graph: VaultGraph) throws -> String? {
        guard let value, value != .null else { return nil }
        return try resolve(
            VaultModelLinks.target(value),
            paths: Set(graph.attachments.keys),
            folder: graph.attachmentRoot
        )
    }

    static func referenced(in graph: VaultGraph) throws -> Set<String> {
        let paths = Set(graph.attachments.keys)
        var result = Set<String>()
        for record in graph.records.values {
            for (key, value) in record.fields {
                let required = ownerField(record.kind) == key && value != .null
                if required {
                    try result.insert(resolve(
                        VaultModelLinks.target(value),
                        paths: paths,
                        folder: graph.attachmentRoot
                    ))
                }
                try collect(value, paths: paths, folder: graph.attachmentRoot, into: &result)
            }
            try collect(.string(record.body), paths: paths, folder: graph.attachmentRoot, into: &result)
        }
        return result
    }

    static func ownerField(_ kind: VaultKind) -> String? {
        switch kind {
        case .aspiration: "cover"
        case .photo: "file"
        default: nil
        }
    }

    private static func collect(
        _ value: VaultValue,
        paths: Set<String>,
        folder: String,
        into result: inout Set<String>
    ) throws {
        switch value {
        case let .array(values):
            for value in values {
                try collect(value, paths: paths, folder: folder, into: &result)
            }
        case let .string(text):
            var references = targets(text)
            if !text.contains("\n"), !text.contains("[["), !text.contains("]("),
               text.contains("Attachments/") || !text.contains("/")
            {
                references.append(text)
            }
            try collect(references, paths: paths, folder: folder, into: &result)
        case let .raw(text):
            try collect(targets(text), paths: paths, folder: folder, into: &result)
        default: break
        }
    }

    private static func collect(
        _ targets: [String],
        paths: Set<String>,
        folder: String,
        into result: inout Set<String>
    ) throws {
        for target in targets where isAttachment(target, paths: paths) {
            try result.insert(resolve(target, paths: paths, folder: folder))
        }
    }

    private static func isAttachment(_ target: String, paths: Set<String>) -> Bool {
        target.contains("Attachments/") || paths.contains(where: {
            $0.split(separator: "/").last == target.split(separator: "/").last
        })
    }

    private static func targets(_ text: String) -> [String] {
        var targets: [String] = []
        var remainder = text[...]
        while let open = remainder.range(of: "[["), let close = remainder[open.upperBound...].range(of: "]]") {
            let inner = remainder[open.upperBound ..< close.lowerBound]
            let target = inner.split(separator: "|", maxSplits: 1).first.map(String.init) ?? ""
            targets.append(target)
            remainder = remainder[close.upperBound...]
        }
        let source = text as NSString
        for regex in markdownTargets {
            for match in regex.matches(in: text, range: NSRange(location: 0, length: source.length)) {
                let range = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
                let target = source.substring(with: range)
                targets.append(target.removingPercentEncoding ?? target)
            }
        }
        return targets
    }
}
