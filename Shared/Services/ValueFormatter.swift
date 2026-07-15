import Foundation

enum ValueFormatter {
    static func format(
        _ value: Double,
        type: MeasurementType,
        unit: String? = nil
    ) -> String {
        switch type {
        case .duration:
            return DurationFormatter.format(value)
        case .count:
            return formatCount(value, unit: unit)
        case .binary:
            return formatDays(value)
        }
    }

    private static func formatCount(
        _ value: Double,
        unit: String?
    ) -> String {
        let number = countString(value)
        if let unit, !unit.isEmpty {
            return "\(number) \(unit)"
        }
        return number
    }

    /// Counts accept decimal entries, so fractions survive (up to two
    /// digits, locale-aware) instead of truncating to zero — while whole
    /// values keep rendering bare ("5", never "5.0").
    private static func countString(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(0 ... 2)).grouping(.never)
        )
    }

    /// Binary magnitudes are counts of done days, so an aggregate reads as
    /// "3 days"; a single day's 0/1 reads as "0 days" / "1 day".
    private static func formatDays(_ value: Double) -> String {
        days(Int(value))
    }

    static func formatShort(
        _ value: Double,
        type: MeasurementType
    ) -> String {
        switch type {
        case .duration:
            return DurationFormatter.format(value)
        case .count, .binary:
            return countString(value)
        }
    }

    /// "1 session" / "n sessions" for summary lines.
    static func sessions(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
    }

    /// "1 day" / "n days" for summary lines.
    static func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    static func chartLabel(
        type: MeasurementType,
        unit: String?
    ) -> String {
        switch type {
        case .duration:
            return "min"
        case .count:
            return unit ?? "count"
        case .binary:
            return "days"
        }
    }

    static func chartValue(
        _ value: Double,
        type: MeasurementType
    ) -> Double {
        switch type {
        case .duration:
            return value / 60
        case .count, .binary:
            return value
        }
    }
}
