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

    static func formatShort(
        _ value: Double,
        type: MeasurementType
    ) -> String {
        switch type {
        case .duration:
            return DurationFormatter.format(value)
        case .count:
            return "\(Int(value))"
        }
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
        }
    }

    static func chartValue(
        _ value: Double,
        type: MeasurementType
    ) -> Double {
        switch type {
        case .duration:
            return value / 60
        case .count:
            return value
        }
    }
}
