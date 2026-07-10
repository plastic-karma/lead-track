import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

enum CSVImporter {
    struct ImportSummary: Equatable {
        var sessionsCreated: Int = 0
        var metricsCreated: Int = 0
        var projectsCreated: Int = 0
        var rowsSkipped: Int = 0
        /// Rows describing a session that already exists (same metric,
        /// instants, and value at export precision) — re-importing a backup
        /// must not double history.
        var duplicatesSkipped: Int = 0
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

    static let expectedHeader = CSVSchema.header

    #if canImport(SwiftData)
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
    #endif

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

    #if canImport(SwiftData)
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
        // A health-linked metric's sessions belong to the HealthKit mirror;
        // imported rows would be overwritten on the next sync and could
        // double real data, so they are skipped instead.
        guard !metric.isHealthLinked else {
            summary.rowsSkipped += 1
            return
        }
        guard cache.registerSession(parsed) else {
            summary.duplicatesSkipped += 1
            return
        }
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
    #endif

    // MARK: - Field Parsing

    /// Undoes the exporter's formula-injection guard so round-trips keep
    /// names stable: one leading apostrophe is stripped when it shields a
    /// formula-leading character.
    static func unescapedName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("'"), trimmed.count > 1 else { return trimmed }
        let rest = String(trimmed.dropFirst())
        if let first = rest.first, "=+-@\t\r".contains(first) {
            return rest
        }
        return trimmed
    }

    /// The start instant: ISO-8601 (the current wire format) first, then
    /// the legacy locale-formatted Date + Start columns for old files.
    static func parseStart(fields: [String]) -> Date? {
        let start = fields[CSVSchema.start.index]
            .trimmingCharacters(in: .whitespaces)
        if let instant = try? Date(start, strategy: .iso8601) {
            return instant
        }
        return parseTimestamp(date: fields[CSVSchema.date.index], time: start)
    }

    /// The end instant, nil when the row has none (running at export time)
    /// or the field doesn't parse (the legacy lenient behavior). A legacy
    /// bare end clock that reads before the start crossed midnight, so it
    /// belongs to the next day — not ~23h before the session began.
    static func parseEnd(fields: [String], startedAt: Date) -> Date? {
        let end = fields[CSVSchema.end.index]
            .trimmingCharacters(in: .whitespaces)
        guard !end.isEmpty else { return nil }
        if let instant = try? Date(end, strategy: .iso8601) {
            return instant
        }
        guard let composed = parseTimestamp(
            date: fields[CSVSchema.date.index], time: end
        ) else { return nil }
        guard composed < startedAt else { return composed }
        return Calendar.current.date(byAdding: .day, value: 1, to: composed)
            ?? composed
    }

    /// nil when the field is empty or unparseable (the lenient legacy
    /// behavior — such a row still imports as a duration).
    static func parseValue(_ field: String) -> Double? {
        Double(field.trimmingCharacters(in: .whitespaces))
    }

    /// Imported files are the app's one untrusted-file input: a NaN or
    /// negative value would poison every downstream aggregate, and future
    /// timestamps corrupt week windows and goal seasons.
    static func isSane(
        started: Date,
        ended: Date?,
        value: Double?,
        now: Date
    ) -> Bool {
        guard started <= now, (ended ?? started) <= now else { return false }
        guard let value else { return true }
        return value.isFinite && value >= 0
    }

    // MARK: - Legacy Date Parsing

    /// Pre-ISO exports wrote the device locale's date and clock formats;
    /// this keeps those files importable on the locale that wrote them.
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

struct ParsedRow {
    let metricName: String
    let projectName: String?
    let measurementType: MeasurementType
    let startedAt: Date
    let endedAt: Date?
    let value: Double?

    init?(fields: [String], now: Date = .now) {
        guard fields.count >= CSVSchema.columnCount else { return nil }
        let name = CSVImporter.unescapedName(fields[CSVSchema.metric.index])
        guard !name.isEmpty,
              let started = CSVImporter.parseStart(fields: fields)
        else { return nil }
        let ended = CSVImporter.parseEnd(fields: fields, startedAt: started)
        let value = CSVImporter.parseValue(fields[CSVSchema.value.index])
        guard CSVImporter.isSane(
            started: started, ended: ended, value: value, now: now
        ) else { return nil }
        metricName = name
        let projectField = CSVImporter.unescapedName(fields[CSVSchema.project.index])
        projectName = projectField.isEmpty ? nil : projectField
        measurementType = MeasurementType(
            rawValue: fields[CSVSchema.type.index].trimmingCharacters(in: .whitespaces)
        ) ?? .duration
        startedAt = started
        endedAt = ended
        self.value = value
    }
}

// MARK: - MetricCache

#if canImport(SwiftData)
private struct MetricCache {
    private var metrics: [String: Metric]
    private var projects: [ProjectKey: Project] = [:]
    private var sessionKeys: Set<SessionKey>

    init(existing: [Metric]) {
        // First one wins on a duplicate name — the schema doesn't enforce
        // name uniqueness (only a UI check does), and trapping here would
        // turn CSV import into a crash.
        metrics = Dictionary(
            existing.map { ($0.name, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for metric in existing {
            for project in metric.projects {
                let key = ProjectKey(
                    metric: metric.name, project: project.name
                )
                projects[key] = project
            }
        }
        sessionKeys = Set(existing.flatMap { metric in
            metric.sessions.map { SessionKey(metricName: metric.name, session: $0) }
        })
    }

    /// Registers the row's session identity; false when an equivalent
    /// session already exists (in the store or earlier in this file), so
    /// re-importing the same export can't double every total.
    mutating func registerSession(_ row: ParsedRow) -> Bool {
        sessionKeys.insert(SessionKey(row)).inserted
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

    /// A session's identity at export precision: both the store's session
    /// and the parsed row funnel through the exporter's own encoders, so
    /// fractional-second and decimal differences can't defeat the match.
    private struct SessionKey: Hashable {
        let metric: String
        let started: String
        let ended: String
        let value: String

        init(metricName: String, session: Session) {
            metric = metricName
            started = CSVSchema.encodeInstant(session.startedAt)
            ended = CSVSchema.encodeInstant(session.endedAt)
            value = CSVSchema.encodeValue(session.value)
        }

        init(_ row: ParsedRow) {
            metric = row.metricName
            started = CSVSchema.encodeInstant(row.startedAt)
            ended = CSVSchema.encodeInstant(row.endedAt)
            value = CSVSchema.encodeValue(row.value)
        }
    }
}
#endif
