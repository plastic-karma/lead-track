import Foundation
import Testing
@testable import lead_track

struct CountLogStyleTests {
    @Test
    func newMetricAsksForTheAmount() {
        let metric = Metric(name: "Words", measurementType: .count)
        #expect(metric.countLogStyle == .askAmount)
        #expect(!metric.logsOneUnitImmediately)
    }

    @Test
    func chosenStyleRoundTripsThroughStorage() {
        let metric = Metric(name: "Prayers", measurementType: .count)
        metric.countLogStyle = .incrementByOne
        #expect(metric.countLogStyleRaw == CountLogStyle.incrementByOne.rawValue)
        #expect(metric.logsOneUnitImmediately)
        metric.countLogStyle = .askAmount
        #expect(metric.countLogStyle == .askAmount)
    }

    @Test
    func unknownStoredStyleFallsBackToAsking() {
        let metric = Metric(name: "Words", measurementType: .count)
        metric.countLogStyleRaw = "somethingNewer"
        #expect(metric.countLogStyle == .askAmount)
    }

    @Test
    func snapshotWithoutStyleReadsAsAsking() {
        let snapshot = WatchMetricSnapshot(
            id: UUID(), name: "Words", measurementType: .count,
            unit: "words", icon: nil, colorName: nil
        )
        #expect(snapshot.countLogStyle == .askAmount)
    }

    @Test
    func snapshotHonorsTheCarriedStyle() {
        let snapshot = WatchMetricSnapshot(
            id: UUID(), name: "Prayers", measurementType: .count,
            unit: nil, icon: nil, colorName: nil,
            countLogStyleRaw: CountLogStyle.incrementByOne.rawValue
        )
        #expect(snapshot.countLogStyle == .incrementByOne)
    }

    @Test
    func snapshotWithUnknownStyleFallsBackToAsking() {
        let snapshot = WatchMetricSnapshot(
            id: UUID(), name: "Words", measurementType: .count,
            unit: nil, icon: nil, colorName: nil,
            countLogStyleRaw: "somethingNewer"
        )
        #expect(snapshot.countLogStyle == .askAmount)
    }
}
