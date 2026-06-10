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
