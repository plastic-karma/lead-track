#if canImport(SwiftUI)
import SwiftUI
#endif

/// One of the muted identity colors a metric can wear. The raw value is what
/// `Metric.colorName` stores; nil falls back to copper, the app accent, so
/// existing metrics need no migration. Values are defined in code because the
/// widget extensions have no asset catalog, and they stay mid-tone and muted
/// so they read on light and dark backgrounds alike. Declaration order is the
/// auto-assignment order for new metrics, so copper, the brand color, leads.
enum MetricColor: String, CaseIterable, Identifiable {
    case copper
    case sage
    case slate
    case lavender
    case moss
    case dustyRose
    case sand
    case teal

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .copper: "Copper"
        case .sage: "Sage"
        case .slate: "Slate"
        case .lavender: "Lavender"
        case .moss: "Moss"
        case .dustyRose: "Dusty Rose"
        case .sand: "Sand"
        case .teal: "Teal"
        }
    }

    /// The least-used color given the names already stored on metrics, so
    /// new metrics differentiate themselves by default. nil names count as
    /// copper (the display fallback); declaration order breaks ties.
    static func nextAvailable(usedNames: [String?]) -> MetricColor {
        var counts: [MetricColor: Int] = [:]
        for name in usedNames {
            let used = name.flatMap(MetricColor.init(rawValue:)) ?? .copper
            counts[used, default: 0] += 1
        }
        return allCases.min {
            counts[$0, default: 0] < counts[$1, default: 0]
        } ?? .copper
    }
}

#if canImport(SwiftUI)
extension MetricColor {
    var color: Color {
        switch self {
        case .copper: Color(red: 0.69, green: 0.37, blue: 0.14)
        case .sage: Color(red: 0.55, green: 0.62, blue: 0.47)
        case .slate: Color(red: 0.42, green: 0.48, blue: 0.55)
        case .lavender: Color(red: 0.58, green: 0.53, blue: 0.71)
        case .moss: Color(red: 0.42, green: 0.50, blue: 0.34)
        case .dustyRose: Color(red: 0.76, green: 0.51, blue: 0.52)
        case .sand: Color(red: 0.76, green: 0.65, blue: 0.45)
        case .teal: Color(red: 0.30, green: 0.55, blue: 0.55)
        }
    }

    /// Resolves a stored color name, falling back to copper for nil or
    /// unrecognized values.
    static func color(named name: String?) -> Color {
        (name.flatMap(MetricColor.init(rawValue:)) ?? .copper).color
    }
}

extension Metric {
    /// The metric's identity color, used on cards, charts, the watch,
    /// widgets, and the Live Activity.
    var displayColor: Color {
        MetricColor.color(named: colorName)
    }
}
#endif
