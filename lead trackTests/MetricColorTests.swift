import Foundation
import Testing
@testable import lead_track

struct MetricColorTests {
    @Test
    func firstMetricGetsTheBrandColor() {
        #expect(MetricColor.nextAvailable(usedNames: []) == .copper)
    }

    @Test
    func picksTheNextColorInDeclarationOrder() {
        let next = MetricColor.nextAvailable(usedNames: ["copper"])
        #expect(next == .sage)
    }

    @Test
    func nilNamesCountAsCopper() {
        let next = MetricColor.nextAvailable(usedNames: [nil])
        #expect(next == .sage)
    }

    @Test
    func unrecognizedNamesCountAsCopper() {
        let next = MetricColor.nextAvailable(usedNames: ["mauve"])
        #expect(next == .sage)
    }

    @Test
    func picksTheLeastUsedColor() {
        let used: [String?] = [
            "copper", "sage", "slate", "lavender",
            "moss", "dustyRose", "sand", "teal",
            "copper", "sage"
        ]
        #expect(MetricColor.nextAvailable(usedNames: used) == .slate)
    }

    @Test
    func cyclesBackToCopperOnceAllColorsAreUsed() {
        let used = MetricColor.allCases.map { $0.rawValue as String? }
        #expect(MetricColor.nextAvailable(usedNames: used) == .copper)
    }
}

/// The WCAG contrast each palette role promises (see `MetricColor`). The
/// backgrounds are `Theme`'s warm neutrals — gray 0.96 (light) and 0.055
/// (dark) plus the +0.018/+0.008 red/green warmth — restated here because
/// `Theme` itself is SwiftUI-only.
struct MetricColorContrastTests {
    static let lightBackground = MetricColor.Components(red: 0.978, green: 0.968, blue: 0.96)
    static let darkBackground = MetricColor.Components(red: 0.073, green: 0.063, blue: 0.055)
    static let white = MetricColor.Components(red: 1, green: 1, blue: 1)

    /// Large ink — hero numerals, icons, progress fills — needs the WCAG
    /// 3:1 large-text floor against the light screen background.
    @Test
    func lightInkReadsOnTheLightBackground() {
        for color in MetricColor.allCases {
            let ratio = contrastRatio(color.lightComponents, Self.lightBackground)
            #expect(ratio >= 3.0, "\(color.rawValue) reads at \(ratio):1")
        }
    }

    /// Dark-mode ink is also used at caption size (chips, legends), so it
    /// holds the full 4.5:1 body-text target against the dark background.
    @Test
    func darkInkReadsOnTheDarkBackground() {
        for color in MetricColor.allCases {
            let ratio = contrastRatio(color.darkComponents, Self.darkBackground)
            #expect(ratio >= 4.5, "\(color.rawValue) reads at \(ratio):1")
        }
    }

    /// Prominent fills sit under white `.headline` labels in both schemes,
    /// so every one holds 4.5:1 against white.
    @Test
    func prominentFillsCarryWhiteLabels() {
        for color in MetricColor.allCases {
            let ratio = contrastRatio(color.prominentComponents, Self.white)
            #expect(ratio >= 4.5, "\(color.rawValue) reads at \(ratio):1")
        }
    }

    private func contrastRatio(
        _ first: MetricColor.Components,
        _ second: MetricColor.Components
    ) -> Double {
        let lighter = max(relativeLuminance(first), relativeLuminance(second))
        let darker = min(relativeLuminance(first), relativeLuminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// WCAG 2.x relative luminance of an sRGB color.
    private func relativeLuminance(_ components: MetricColor.Components) -> Double {
        0.2126 * linearized(components.red)
            + 0.7152 * linearized(components.green)
            + 0.0722 * linearized(components.blue)
    }

    private func linearized(_ channel: Double) -> Double {
        channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
    }
}
