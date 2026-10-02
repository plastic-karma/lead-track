import Foundation

struct VaultModelLinks {
    let graph: VaultGraph
    let models: [UUID: any VaultModel]

    init(graph: VaultGraph, models: VaultModels) {
        self.graph = graph
        self.models = Dictionary(uniqueKeysWithValues: models.all.compactMap { model in
            model.stableID.map { ($0, model) }
        })
    }

    static func link(_ model: (any VaultModel)?) throws -> VaultValue {
        guard let model else { return .null }
        guard let id = model.stableID else { throw VaultError.invalid("Relationship points outside exported models") }
        return linkID(id)
    }

    static func linkID(_ id: UUID?) -> VaultValue {
        id.map { .string("[[\($0.uuidString.lowercased())]]") } ?? .null
    }

    static func target(_ value: VaultValue) throws -> String {
        let text = try String.decodeVault(value)
        guard text.hasPrefix("[["), text.hasSuffix("]]"), text.count > 4 else {
            throw VaultError.invalid("Relationships must be wikilinks")
        }
        let inner = text.dropFirst(2).dropLast(2)
        let path = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)[0]
        guard !path.contains("#"), !path.isEmpty else { throw VaultError.invalid("Invalid relationship link") }
        return String(path)
    }

    func id(_ value: VaultValue) throws -> UUID {
        let target = try Self.target(value)
        if let uuid = UUID(uuidString: target), graph.records[uuid] != nil { return uuid }
        let stripped = target.hasSuffix(".md") ? String(target.dropLast(3)) : target
        let matches = graph.records.values.filter { record in
            let path = record.path.hasSuffix(".md") ? String(record.path.dropLast(3)) : record.path
            let basename = path.split(separator: "/").last.map(String.init)
            let aliases = record.fields["aliases"]
            let aliasMatch: Bool
            if case let .array(values) = aliases { aliasMatch = values.contains(.string(target)) }
            else { aliasMatch = false }
            return path == stripped || stripped.hasSuffix("/" + path) || basename == stripped || aliasMatch
        }
        guard matches.count == 1, let match = matches.first else {
            throw VaultError.invalid("Dangling or ambiguous relationship: \(target)")
        }
        return match.id
    }

    func one<Model: VaultModel>(_ record: VaultRecord, _ key: String, required: Bool = false) throws -> Model? {
        guard let value = record.fields[key], value != .null else {
            if required { throw VaultError.invalid("Missing \(record.kind.rawValue).\(key)") }
            return nil
        }
        guard let model = try models[id(value)] as? Model else {
            throw VaultError.invalid("Wrong relationship type for \(key)")
        }
        return model
    }

    func many<Model: VaultModel>(_ record: VaultRecord, _ key: String) throws -> [Model] {
        guard let field = record.fields[key], field != .null else { return [] }
        guard case let .array(values) = field else {
            throw VaultError.invalid("Expected relationship list \(key)")
        }
        var seen = Set<UUID>()
        return try values.map { value in
            let id = try id(value)
            guard seen.insert(id).inserted, let model = models[id] as? Model else {
                throw VaultError.invalid("Duplicate or incorrectly typed relationship \(key)")
            }
            return model
        }
    }

    func attachment(_ record: VaultRecord, _ key: String, required: Bool = false) throws -> Data? {
        guard let value = record.fields[key], value != .null else {
            if required { throw VaultError.invalid("Missing attachment \(key)") }
            return nil
        }
        guard let path = try VaultAttachmentLinks.path(value, graph: graph), let data = graph.attachments[path] else {
            throw VaultError.invalid("Missing attachment \(key)")
        }
        return data
    }

    static func safePath(_ path: String) -> Bool {
        !path.hasPrefix("/") && !path.contains("\\")
            && !path.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            && path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func imageExtension(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "png" }
        if data.starts(with: Data("GIF8".utf8)) { return "gif" }
        if data.starts(with: Data("BM".utf8)) { return "bmp" }
        if data.starts(with: [0x49, 0x49, 0x2A, 0]) || data.starts(with: [0x4D, 0x4D, 0, 0x2A]) { return "tiff" }
        return containerExtension(data)
    }

    private static func containerExtension(_ data: Data) -> String {
        guard data.count >= 12 else { return "bin" }
        let type = String(decoding: data.dropFirst(8).prefix(4), as: UTF8.self)
        if data.starts(with: Data("RIFF".utf8)), type == "WEBP" { return "webp" }
        if String(decoding: data.dropFirst(4).prefix(4), as: UTF8.self) == "ftyp" {
            if ["avif", "avis"].contains(type) { return "avif" }
            if ["heic", "heix", "hevc", "hevx"].contains(type) { return "heic" }
            if ["mif1", "msf1"].contains(type) { return "heif" }
        }
        // Unknown historical bytes are preserved, never falsely labelled JPEG.
        return "bin"
    }
}
