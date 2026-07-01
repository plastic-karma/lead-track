#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif

/// One of the muted identity colors a metric can wear. The raw value is what
/// `Metric.colorName` stores; nil falls back to copper, the app accent, so
/// existing metrics need no migration. Values are defined in code because the
/// widget extensions have no asset catalog. Each color carries three tuned
/// variants (see `Components`) — light-mode ink, brighter dark-mode ink, and
/// a deeper fill for white-labelled buttons — so tinted surfaces hold WCAG
/// contrast in both schemes. Declaration order is the auto-assignment order
/// for new metrics, so copper, the brand color, leads.
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

// MARK: - Palette values

extension MetricColor {
    /// sRGB components for one palette role. Platform-neutral (unlike
    /// `Color`) so the overlay-package tests can verify the contrast target
    /// each role promises.
    struct Components {
        let red: Double
        let green: Double
        let blue: Double
    }

    /// Identity ink and fills in light mode: every value holds at least 3:1
    /// against the light screen background (`Theme`'s warm 0.96 neutral),
    /// the WCAG floor for large numerals, icons, and other big ink.
    var lightComponents: Components {
        switch self {
        case .copper: Components(red: 0.69, green: 0.37, blue: 0.14)
        case .sage: Components(red: 0.52, green: 0.58, blue: 0.44)
        case .slate: Components(red: 0.42, green: 0.48, blue: 0.55)
        case .lavender: Components(red: 0.58, green: 0.53, blue: 0.71)
        case .moss: Components(red: 0.42, green: 0.50, blue: 0.34)
        case .dustyRose: Components(red: 0.74, green: 0.50, blue: 0.51)
        case .sand: Components(red: 0.64, green: 0.55, blue: 0.38)
        case .teal: Components(red: 0.30, green: 0.55, blue: 0.55)
        }
    }

    /// Identity ink in dark mode, lifted toward white the way the asset
    /// catalog lifts the copper accent (which this copper matches): every
    /// value holds at least 4.5:1 against the dark screen background, so
    /// even caption-sized tinted text stays legible.
    var darkComponents: Components {
        switch self {
        case .copper: Components(red: 0.91, green: 0.60, blue: 0.34)
        case .sage: Components(red: 0.66, green: 0.71, blue: 0.61)
        case .slate: Components(red: 0.59, green: 0.64, blue: 0.69)
        case .lavender: Components(red: 0.71, green: 0.67, blue: 0.80)
        case .moss: Components(red: 0.59, green: 0.65, blue: 0.54)
        case .dustyRose: Components(red: 0.82, green: 0.65, blue: 0.66)
        case .sand: Components(red: 0.75, green: 0.69, blue: 0.57)
        case .teal: Components(red: 0.51, green: 0.69, blue: 0.69)
        }
    }

    /// The fill behind a white label — prominent record buttons in both
    /// schemes: every value holds at least 4.5:1 against white, the WCAG
    /// target for body-sized text.
    var prominentComponents: Components {
        switch self {
        case .copper: Components(red: 0.69, green: 0.37, blue: 0.14)
        case .sage: Components(red: 0.43, green: 0.48, blue: 0.37)
        case .slate: Components(red: 0.41, green: 0.47, blue: 0.54)
        case .lavender: Components(red: 0.49, green: 0.44, blue: 0.60)
        case .moss: Components(red: 0.41, green: 0.49, blue: 0.34)
        case .dustyRose: Components(red: 0.61, green: 0.41, blue: 0.42)
        case .sand: Components(red: 0.53, green: 0.45, blue: 0.31)
        case .teal: Components(red: 0.28, green: 0.50, blue: 0.50)
        }
    }
}

#if canImport(SwiftUI)
extension MetricColor.Components {
    /// The components as a fixed (non-adaptive) SwiftUI color.
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

extension MetricColor {
    /// The identity ink, resolved per light/dark trait. The watch has no
    /// light mode and always wears the dark variant.
    var color: Color {
        Self.adaptive(light: lightComponents, dark: darkComponents)
    }

    /// The fill for buttons carrying white labels, deep enough to keep the
    /// label readable in both schemes.
    var prominentColor: Color {
        prominentComponents.color
    }

    /// Resolves a stored color name, falling back to copper for nil or
    /// unrecognized values.
    static func color(named name: String?) -> Color {
        resolve(name).color
    }

    /// The white-label button fill for a stored color name
    /// (see `prominentColor`).
    static func prominentColor(named name: String?) -> Color {
        resolve(name).prominentColor
    }

    private static func resolve(_ name: String?) -> MetricColor {
        name.flatMap(MetricColor.init(rawValue:)) ?? .copper
    }

    private static func adaptive(light: Components, dark: Components) -> Color {
        #if os(watchOS)
        dark.color
        #elseif canImport(UIKit)
        Color(uiColor: UIColor { traits in
            let variant = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: variant.red, green: variant.green, blue: variant.blue, alpha: 1)
        })
        #else
        light.color
        #endif
    }
}

extension Metric {
    /// The metric's identity color, used on cards, charts, the watch,
    /// widgets, and the Live Activity.
    var displayColor: Color {
        MetricColor.color(named: colorName)
    }

    /// The fill behind the metric's white-labelled record buttons.
    var prominentColor: Color {
        MetricColor.prominentColor(named: colorName)
    }
}

extension WatchMetricSnapshot {
    /// The snapshot's identity color on the watch and in its widgets.
    var displayColor: Color {
        MetricColor.color(named: colorName)
    }

    /// The fill behind the snapshot's white-labelled buttons.
    var prominentColor: Color {
        MetricColor.prominentColor(named: colorName)
    }
}

extension Aspiration {
    /// The aspiration's identity color, reusing the metric palette for its
    /// cover band, icon, and back-link chips.
    var displayColor: Color {
        MetricColor.color(named: colorName)
    }

    /// The fill behind the aspiration's white-labelled controls.
    var prominentColor: Color {
        MetricColor.prominentColor(named: colorName)
    }
}

#if canImport(ActivityKit)
extension TimerActivityAttributes {
    /// The Live Activity's identity color.
    var displayColor: Color {
        MetricColor.color(named: colorName)
    }
}
#endif
#endif
