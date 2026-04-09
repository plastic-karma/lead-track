import Foundation
import SwiftData

enum ExportTimeRange: String, CaseIterable {
    case last7Days = "Last 7 Days"
    case lastMonth = "Last Month"
    case yearToDate = "Year to Date"
    case lastYear = "Last Year"
    case all = "All Time"
}

enum ExportScope: Hashable {
    case all
    case metric(PersistentIdentifier)
    case project(PersistentIdentifier)
}

enum CSVExporter {
    static func exportFile(
        from sessions: [Session]
    ) -> URL {
        let csv = buildCSV(from: sessions)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("lead-track-export.csv")
        try? csv.write(
            to: url, atomically: true, encoding: .utf8
        )
        return url
    }

    static func buildCSV(from sessions: [Session]) -> String {
        var lines = [header]
        for session in sessions {
            lines.append(row(for: session))
        }
        return lines.joined(separator: "\n")
    }

    static func cutoffDate(
        for timeRange: ExportTimeRange
    ) -> Date? {
        let cal = Calendar.current
        let now = Date.now
        switch timeRange {
        case .last7Days:
            return cal.date(
                byAdding: .day, value: -6,
                to: cal.startOfDay(for: now)
            )
        case .lastMonth:
            return cal.date(
                byAdding: .month, value: -1, to: now
            )
        case .yearToDate:
            return cal.date(
                from: cal.dateComponents([.year], from: now)
            )
        case .lastYear:
            return cal.date(
                byAdding: .year, value: -1, to: now
            )
        case .all:
            return nil
        }
    }

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

    static func filterByTime(
        _ sessions: [Session],
        cutoff: Date?
    ) -> [Session] {
        guard let cutoff else { return sessions }
        return sessions.filter { $0.startedAt >= cutoff }
    }

    // MARK: - CSV Formatting

    private static let header =
        "Metric,Project,Date,Start,End,Duration (s),Value,Type"

    private static func row(for session: Session) -> String {
        let metric = escape(session.metric?.name ?? "")
        let project = escape(session.project?.name ?? "")
        let date = session.startedAt.formatted(
            date: .numeric, time: .omitted
        )
        let start = session.startedAt.formatted(
            date: .omitted, time: .standard
        )
        let end = session.endedAt?.formatted(
            date: .omitted, time: .standard
        ) ?? ""
        let duration = String(format: "%.0f", session.duration)
        let value = session.value.map {
            String(format: "%.1f", $0)
        } ?? ""
        let type = session.metric?.measurementType.rawValue
            ?? "duration"
        return "\(metric),\(project),\(date),\(start),"
            + "\(end),\(duration),\(value),\(type)"
    }

    static func escape(_ text: String) -> String {
        if text.contains(",") || text.contains("\"")
            || text.contains("\n")
        {
            return "\"\(text.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return text
    }
}
