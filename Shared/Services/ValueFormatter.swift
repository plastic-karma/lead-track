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
        let intValue = Int(value)
        if let unit, !unit.isEmpty {
            return "\(intValue) \(unit)"
        }
        return "\(intValue)"
    }

    /// Binary magnitudes are counts of done days, so an aggregate reads as
    /// "3 days"; a single day's 0/1 reads as "0 days" / "1 day".
    private static func formatDays(_ value: Double) -> String {
        let days = Int(value)
        return days == 1 ? "1 day" : "\(days) days"
    }

    static func formatShort(
        _ value: Double,
        type: MeasurementType
    ) -> String {
        switch type {
        case .duration:
            return DurationFormatter.format(value)
        case .count, .binary:
            return "\(Int(value))"
        }
    }

    /// "1 session" / "n sessions" for summary lines.
    static func sessions(_ count: Int) -> String {
        count == 1 ? "1 session" : "\(count) sessions"
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
