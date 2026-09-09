import Foundation

/// Saves a shelving change without rolling back unrelated pending edits.
enum AspirationShelving {
    static func setArchived(
        _ archived: Bool,
        for aspiration: Aspiration,
        at date: Date = .now,
        save: () throws -> Void
    ) throws {
        let previous = aspiration.archivedAt
        if archived {
            aspiration.archive(at: date)
        } else {
            aspiration.unarchive()
        }
        do {
            try save()
        } catch {
            aspiration.archivedAt = previous
            throw error
        }
    }
}
