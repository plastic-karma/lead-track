import Foundation

enum VaultBases {
    static func files() -> [String: Data] {
        Dictionary(uniqueKeysWithValues: VaultKind.allCases.map { kind in
            (kind.folder + ".base", Data(document(kind).utf8))
        })
    }

    private static func document(_ kind: VaultKind) -> String {
        let columns = (["formula.record"] + columns(kind)).map { "      - \($0)\n" }.joined()
        return """
        filters:
          and:
            - file.ext == "md"
            - file.inFolder(this.file.folder)
            - leadstone_type == "\(kind.rawValue)"
        formulas:
          record: 'file.asLink(if(note.title, note.title, if(note.name, note.name, if(note.aliases, note.aliases[0], file.name))))'
        properties:
          formula.record:
            displayName: Record
        views:
          - type: table
            name: \(kind.folder)
            order:
        """ + "\n" + columns
    }

    private static func columns(_ kind: VaultKind) -> [String] {
        switch kind {
        case .aspiration: ["note.created_at"]
        case .metric: ["note.measurement_type", "note.unit", "note.created_at"]
        case .project: ["note.status", "note.metric", "note.started_at", "note.finished_at"]
        case .session: ["note.started_at", "note.metric", "note.project", "note.value", "note.ended_at"]
        case .principle: ["note.aspiration", "note.created_at"]
        case .intention: ["note.kind", "note.week_start", "note.target", "note.aspiration"]
        case .checkIn: ["note.week_start", "note.rating", "note.aspiration"]
        case .moment: ["note.occurred_at", "note.aspiration"]
        case .photo: ["note.moment", "note.sort_index", "note.file"]
        }
    }
}
