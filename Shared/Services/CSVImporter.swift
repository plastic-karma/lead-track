import Foundation
import SwiftData

enum CSVImporter {
    struct ImportSummary: Equatable {
        var sessionsCreated: Int = 0
        var metricsCreated: Int = 0
        var projectsCreated: Int = 0
        var rowsSkipped: Int = 0
    }

    enum ImportError: LocalizedError {
        case emptyFile
        case invalidHeader

        var errorDescription: String? {
            switch self {
            case .emptyFile:
                "The CSV file is empty."
            case .invalidHeader:
                "The CSV header doesn't match the expected format."
            }
        }
    }

    static let expectedHeader =
        "Metric,Project,Date,Start,End,Duration (s),Value,Type"

    @discardableResult
    static func importCSV(
        contents: String,
        existingMetrics: [Metric],
        context: ModelContext
    ) throws -> ImportSummary {
        let rows = parseRows(contents)
        guard let header = rows.first else {
            throw ImportError.emptyFile
        }
        guard isValidHeader(header) else {
            throw ImportError.invalidHeader
        }
        var cache = MetricCache(existing: existingMetrics)
        var summary = ImportSummary()
        for fields in rows.dropFirst() where !fields.allSatisfy(\.isEmpty) {
            applyRow(
                fields,
                cache: &cache,
                summary: &summary,
                context: context
            )
        }
        return summary
    }

    static func isValidHeader(_ fields: [String]) -> Bool {
        let trimmed = fields.map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        return trimmed == expectedHeader.split(separator: ",").map(String.init)
    }

    static func parseRows(_ text: String) -> [[String]] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        var parser = RowParser()
        for char in normalized {
            parser.feed(char)
        }
        return parser.finish()
    }

    // MARK: - Row Application

    private static func applyRow(
        _ fields: [String],
        cache: inout MetricCache,
        summary: inout ImportSummary,
        context: ModelContext
    ) {
        guard let parsed = ParsedRow(fields: fields) else {
            summary.rowsSkipped += 1
            return
        }
        let metric = cache.findOrCreate(
            metricNamed: parsed.metricName,
            type: parsed.measurementType,
            summary: &summary,
            context: context
        )
        let project = parsed.projectName.flatMap { name in
            cache.findOrCreate(
                projectNamed: name,
                in: metric,
                summary: &summary,
                context: context
            )
        }
        let session = Session(
            metric: metric,
            project: project,
            startedAt: parsed.startedAt,
            endedAt: parsed.endedAt,
            value: parsed.value
        )
        context.insert(session)
        summary.sessionsCreated += 1
    }

    // MARK: - Date Parsing

    static func parseTimestamp(date: String, time: String) -> Date? {
        let cal = Calendar.current
        let dateStrategy = Date.FormatStyle(
            date: .numeric, time: .omitted
        )
        let timeStrategy = Date.FormatStyle(
            date: .omitted, time: .standard
        )
        guard let day = try? Date(date, strategy: dateStrategy),
              let clock = try? Date(time, strategy: timeStrategy)
        else { return nil }
        var components = cal.dateComponents(
            [.year, .month, .day], from: day
        )
        let timeParts = cal.dateComponents(
            [.hour, .minute, .second], from: clock
        )
        components.hour = timeParts.hour
        components.minute = timeParts.minute
        components.second = timeParts.second
        return cal.date(from: components)
    }
}

// MARK: - RowParser

private struct RowParser {
    private var rows: [[String]] = []
    private var row: [String] = []
    private var field = ""
    private var inQuotes = false
    private var pendingQuote = false

    mutating func feed(_ char: Character) {
        if pendingQuote {
            pendingQuote = false
            if char == "\"" {
                field.append("\"")
                return
            }
            inQuotes = false
        }
        if inQuotes {
            consumeQuoted(char)
        } else {
            consumeUnquoted(char)
        }
    }

    mutating func finish() -> [[String]] {
        if pendingQuote { inQuotes = false }
        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }
        return rows
    }

    private mutating func consumeQuoted(_ char: Character) {
        if char == "\"" {
            pendingQuote = true
        } else {
            field.append(char)
        }
    }

    private mutating func consumeUnquoted(_ char: Character) {
        switch char {
        case "\"":
            inQuotes = true
        case ",":
            row.append(field)
            field = ""
        case "\n":
            row.append(field)
            rows.append(row)
            row = []
            field = ""
        default:
            field.append(char)
        }
    }
}

// MARK: - ParsedRow

private struct ParsedRow {
    let metricName: String
    let projectName: String?
    let measurementType: MeasurementType
    let startedAt: Date
    let endedAt: Date?
    let value: Double?

    init?(fields: [String]) {
        guard fields.count >= 8 else { return nil }
        let name = fields[0].trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return nil }
        guard let started = CSVImporter.parseTimestamp(
            date: fields[2], time: fields[3]
        ) else { return nil }
        metricName = name
        let projectField = fields[1].trimmingCharacters(in: .whitespaces)
        projectName = projectField.isEmpty ? nil : projectField
        measurementType = MeasurementType(
            rawValue: fields[7].trimmingCharacters(in: .whitespaces)
        ) ?? .duration
        startedAt = started
        endedAt = CSVImporter.parseTimestamp(
            date: fields[2], time: fields[4]
        )
        value = Double(fields[6].trimmingCharacters(in: .whitespaces))
    }
}

// MARK: - MetricCache

private struct MetricCache {
    private var metrics: [String: Metric]
    private var projects: [ProjectKey: Project] = [:]

    init(existing: [Metric]) {
        metrics = Dictionary(
            uniqueKeysWithValues: existing.map { ($0.name, $0) }
        )
        for metric in existing {
            for project in metric.projects {
                let key = ProjectKey(
                    metric: metric.name, project: project.name
                )
                projects[key] = project
            }
        }
    }

    mutating func findOrCreate(
        metricNamed name: String,
        type: MeasurementType,
        summary: inout CSVImporter.ImportSummary,
        context: ModelContext
    ) -> Metric {
        if let existing = metrics[name] { return existing }
        let metric = Metric(name: name, measurementType: type)
        context.insert(metric)
        metrics[name] = metric
        summary.metricsCreated += 1
        return metric
    }

    mutating func findOrCreate(
        projectNamed name: String,
        in metric: Metric,
        summary: inout CSVImporter.ImportSummary,
        context: ModelContext
    ) -> Project {
        let key = ProjectKey(metric: metric.name, project: name)
        if let existing = projects[key] { return existing }
        let project = Project(name: name, metric: metric)
        context.insert(project)
        projects[key] = project
        summary.projectsCreated += 1
        return project
    }

    private struct ProjectKey: Hashable {
        let metric: String
        let project: String
    }
}
