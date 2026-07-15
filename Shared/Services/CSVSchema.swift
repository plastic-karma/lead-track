import Foundation

/// The CSV backup format's column layout — the one place the schema lives.
/// The exporter's header, the importer's validation and field indices, and
/// the duplicate-detection keys all derive from it, so adding a column can't
/// silently shift the others out of agreement.
enum CSVSchema: Int, CaseIterable {
    case metric
    case project
    case date
    case start
    case end
    case duration
    case value
    case type

    var title: String {
        switch self {
        case .metric: "Metric"
        case .project: "Project"
        case .date: "Date"
        case .start: "Start"
        case .end: "End"
        case .duration: "Duration (s)"
        case .value: "Value"
        case .type: "Type"
        }
    }

    var index: Int {
        rawValue
    }

    static var header: String {
        allCases.map(\.title).joined(separator: ",")
    }

    static var columnCount: Int {
        allCases.count
    }
}

extension CSVSchema {
    /// Wire encoding of an instant: fixed ISO-8601 in UTC. The previous
    /// locale-sensitive form stopped round-tripping after any region or
    /// 12/24-hour change, silently dropping every row on import.
    static func encodeInstant(_ date: Date?) -> String {
        date?.formatted(.iso8601) ?? ""
    }

    /// Wire encoding of the Value column. The importer's duplicate
    /// detection compares through the same encoding, so store precision and
    /// file precision always agree.
    static func encodeValue(_ value: Double?) -> String {
        value.map { String(format: "%.1f", $0) } ?? ""
    }
}
