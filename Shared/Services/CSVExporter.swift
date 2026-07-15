import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
enum ExportScope: Hashable {
    case all
    case metric(PersistentIdentifier)
    case project(PersistentIdentifier)
}
#endif

enum CSVExporter {
    /// Writes the export to the temp file, or nil when the write fails. Any
    /// previous export is removed first, so a failed write can never hand
    /// the share sheet a stale file with a different scope or range.
    static func exportFile(
        from sessions: [Session]
    ) -> URL? {
        let csv = buildCSV(from: sessions)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lead-track-export.csv")
        try? FileManager.default.removeItem(at: url)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func buildCSV(from sessions: [Session]) -> String {
        var lines = [CSVSchema.header]
        for session in sessions {
            lines.append(row(for: session))
        }
        return lines.joined(separator: "\n")
    }

    #if canImport(SwiftData)
    static func filterByScope(
        _ sessions: [Session],
        scope: ExportScope
    ) -> [Session] {
        switch scope {
        case .all:
            return sessions
        case let .metric(id):
            return sessions.filter {
                $0.metric?.persistentModelID == id
            }
        case let .project(id):
            return sessions.filter {
                $0.project?.persistentModelID == id
            }
        }
    }
    #endif

    static func filterByTime(
        _ sessions: [Session],
        cutoff: Date?
    ) -> [Session] {
        guard let cutoff else { return sessions }
        return sessions.filter { $0.startedAt >= cutoff }
    }

    // MARK: - CSV Formatting

    /// The user's local calendar day, printed fixed ("2026-07-10") for
    /// spreadsheet grouping; the importer reads the Start/End instants.
    private static let localDay = Date.ISO8601FormatStyle(timeZone: .current)
        .year().month().day()

    /// One row in `CSVSchema` column order. Start/End carry full ISO-8601
    /// instants: locale-proof to re-import, and an end that crossed
    /// midnight keeps its real date instead of borrowing the start's.
    private static func row(for session: Session) -> String {
        let fields = [
            escape(session.metric?.name ?? ""),
            escape(session.project?.name ?? ""),
            session.startedAt.formatted(localDay),
            CSVSchema.encodeInstant(session.startedAt),
            CSVSchema.encodeInstant(session.endedAt),
            String(format: "%.0f", session.duration),
            CSVSchema.encodeValue(session.value),
            session.metric?.measurementType.rawValue ?? "duration"
        ]
        return fields.joined(separator: ",")
    }

    /// RFC-4180 quoting plus spreadsheet-formula neutralization (CWE-1236):
    /// a field starting with =, +, -, @, tab, or CR executes as a formula
    /// when the export is opened in Excel/LibreOffice/Numbers — and names
    /// can enter the store from an untrusted imported file. Guarded fields
    /// get a leading apostrophe, which the importer strips back off.
    static func escape(_ text: String) -> String {
        var text = text
        if let first = text.first, "=+-@\t\r".contains(first) {
            text = "'\(text)"
        }
        if text.contains(",") || text.contains("\"")
            || text.contains("\n")
        {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
