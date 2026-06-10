import SwiftUI

/// One of the muted identity colors a metric can wear. The raw value is what
/// `Metric.colorName` stores; nil falls back to copper, the app accent, so
/// existing metrics need no migration. Values are defined in code because the
/// widget extensions have no asset catalog, and they stay mid-tone and muted
/// so they read on light and dark backgrounds alike.
enum MetricColor: String, CaseIterable, Identifiable {
    case sage
    case copper
    case slate
    case lavender
    case moss
    case dustyRose
    case sand
    case teal

    var id: String {
        rawValue
    }

    var color: Color {
        switch self {
        case .sage: Color(red: 0.55, green: 0.62, blue: 0.47)
        case .copper: Color(red: 0.78, green: 0.44, blue: 0.18)
        case .slate: Color(red: 0.42, green: 0.48, blue: 0.55)
        case .lavender: Color(red: 0.58, green: 0.53, blue: 0.71)
        case .moss: Color(red: 0.42, green: 0.50, blue: 0.34)
        case .dustyRose: Color(red: 0.76, green: 0.51, blue: 0.52)
        case .sand: Color(red: 0.76, green: 0.65, blue: 0.45)
        case .teal: Color(red: 0.30, green: 0.55, blue: 0.55)
        }
    }

    var label: String {
        switch self {
        case .sage: "Sage"
        case .copper: "Copper"
        case .slate: "Slate"
        case .lavender: "Lavender"
        case .moss: "Moss"
        case .dustyRose: "Dusty Rose"
        case .sand: "Sand"
        case .teal: "Teal"
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
