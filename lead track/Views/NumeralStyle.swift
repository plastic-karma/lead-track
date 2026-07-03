import SwiftUI

/// The app's numeric type scale. Every standalone data numeral — a value the
/// user reads as content — renders at exactly one of these three sizes,
/// always in rounded digits. Numerals that annotate an instrument (ring
/// percents, streak badges, chart axes and inline labels) are furniture,
/// not content, and stay in plain text styles.
enum NumeralSize {
    /// The one value a screen is about: the metric detail's today value.
    case hero
    /// A dashboard card's value.
    case value
    /// A statistic in a grid or an inline readout in a row.
    case stat

    fileprivate var font: Font {
        switch self {
        case .hero: .system(size: 56, weight: .bold, design: .rounded)
        case .value: .system(size: 26, weight: .semibold, design: .rounded)
        case .stat: .system(.headline, design: .rounded)
        }
    }

    /// Tightened tracking on the larger sizes, so the hero numbers read as a
    /// deliberate display treatment rather than default body digits.
    fileprivate var tracking: CGFloat {
        switch self {
        case .hero: -1
        case .value: -0.4
        case .stat: 0
        }
    }
}

extension View {
    /// Puts a numeral on the app's three-size scale; digits are monospaced
    /// so live values don't jitter as they count.
    func numeralStyle(_ size: NumeralSize) -> some View {
        font(size.font)
            .monospacedDigit()
            .tracking(size.tracking)
    }
}
