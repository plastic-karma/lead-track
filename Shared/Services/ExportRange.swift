import Foundation

/// The window a data export covers. Fixed-length windows are day-aligned —
/// they open at a local midnight, so a day-by-day export never starts
/// mid-day. Month and year windows carry their length, chosen in the export
/// form's stepper.
enum ExportRange: Hashable {
    case last7Days
    case lastMonths(Int)
    case yearToDate
    case lastYears(Int)
    case allTime
}

// MARK: - Cutoff

extension ExportRange {
    /// The inclusive lower bound sessions, moments, and weeks are filtered
    /// by, or nil when the export reaches all the way back.
    func cutoff(now: Date = .now, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        switch self {
        case .last7Days:
            return calendar.date(byAdding: .day, value: -6, to: today)
        case let .lastMonths(months):
            return calendar.date(byAdding: .month, value: -months, to: today)
        case .yearToDate:
            return calendar.date(from: calendar.dateComponents([.year], from: now))
        case let .lastYears(years):
            return calendar.date(byAdding: .year, value: -years, to: today)
        case .allTime:
            return nil
        }
    }
}

// MARK: - Labels

extension ExportRange {
    /// The picker-row and document wording, spelling the count out and
    /// dropping it when it is one: "Last 7 Days", "Last 3 Months",
    /// "Last Month".
    var label: String {
        switch self {
        case .last7Days: "Last 7 Days"
        case let .lastMonths(months): months == 1 ? "Last Month" : "Last \(months) Months"
        case .yearToDate: "Year to Date"
        case let .lastYears(years): years == 1 ? "Last Year" : "Last \(years) Years"
        case .allTime: "All Time"
        }
    }

    /// The label as a filename fragment: "last-3-months".
    var fileSlug: String {
        label.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}

// MARK: - Form Selection

extension ExportRange {
    /// The five selectable shapes, separated from the month/year counts so
    /// the export form can drive one picker plus a stepper.
    enum Kind: CaseIterable {
        case last7Days
        case lastMonths
        case yearToDate
        case lastYears
        case allTime
    }

    /// Resolves a picked shape against the form's current counts.
    static func make(_ kind: Kind, months: Int, years: Int) -> ExportRange {
        switch kind {
        case .last7Days: .last7Days
        case .lastMonths: .lastMonths(months)
        case .yearToDate: .yearToDate
        case .lastYears: .lastYears(years)
        case .allTime: .allTime
        }
    }
}

// MARK: - Format

/// What the export produces: the LLM-ready markdown report, or the raw
/// session table as CSV.
enum ExportFormat: String, CaseIterable {
    case markdown = "Markdown"
    case csv = "CSV"
}
