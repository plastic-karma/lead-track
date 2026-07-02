import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Creation-time invariants: every combination `Intention.make` accepts or
/// refuses, positive and negative.
struct IntentionInvariantTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func makeAspiration() -> Aspiration {
        let aspiration = Aspiration(title: "Vitality")
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric(type: MeasurementType = .duration) -> Metric {
        let metric = Metric(name: "Walking", measurementType: type)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func expectRejected(
        _ expected: Intention.ValidationError,
        kind: IntentionKind,
        mode: DerivedMode? = nil,
        metric: Metric? = nil,
        perDay: Bool = false,
        target: Double? = nil
    ) {
        #expect(throws: expected) {
            try Intention.make(
                title: "3 long walks", kind: kind, aspiration: makeAspiration(),
                derivedMode: mode, metric: metric, perDay: perDay, target: target
            )
        }
    }
}

// MARK: - Ownership & week normalization

extension IntentionInvariantTests {
    @Test
    func creationBindsAspirationAndNormalizesWeekStart() throws {
        let createdAt = Date.now
        let intention = try Intention.make(
            title: "be present", kind: .reflective, aspiration: makeAspiration(), createdAt: createdAt
        )
        #expect(intention.aspiration != nil)
        #expect(intention.weekStart == calendar.dateInterval(of: .weekOfYear, for: createdAt)?.start)
        #expect(intention.isOpen)
        #expect(intention.outcome == nil)
    }
}

// MARK: - Reflective carries nothing

extension IntentionInvariantTests {
    @Test
    func reflectiveRejectsEveryPieceOfMachinery() {
        expectRejected(.reflectiveCarriesMachinery, kind: .reflective, target: 3)
        expectRejected(.reflectiveCarriesMachinery, kind: .reflective, perDay: true)
        expectRejected(.reflectiveCarriesMachinery, kind: .reflective, metric: makeMetric())
        expectRejected(.reflectiveCarriesMachinery, kind: .reflective, mode: .sessionCount)
    }
}

// MARK: - Counted

extension IntentionInvariantTests {
    @Test
    func countedWeeklyNeedsAWholeTargetOfAtLeastOne() throws {
        expectRejected(.invalidTarget, kind: .counted)
        expectRejected(.invalidTarget, kind: .counted, target: 0)
        expectRejected(.invalidTarget, kind: .counted, target: 0.5)
        expectRejected(.invalidTarget, kind: .counted, target: 1.5)
        let intention = try Intention.make(title: "3 walks", kind: .counted, aspiration: makeAspiration(), target: 3)
        #expect(intention.target == 3)
    }

    @Test
    func countedRejectsDerivedMachinery() {
        expectRejected(.countedCarriesDerivedMachinery, kind: .counted, metric: makeMetric(), target: 3)
        expectRejected(.countedCarriesDerivedMachinery, kind: .counted, mode: .sessionCount, target: 3)
    }
}

// MARK: - Derived

extension IntentionInvariantTests {
    @Test
    func derivedNeedsMetricAndMode() {
        expectRejected(.derivedMissingMetricOrMode, kind: .derived, mode: .sessionCount, target: 3)
        expectRejected(.derivedMissingMetricOrMode, kind: .derived, metric: makeMetric(), target: 3)
    }

    @Test
    func derivedSessionCountNeedsAWholeTarget() throws {
        expectRejected(.invalidTarget, kind: .derived, mode: .sessionCount, metric: makeMetric(), target: 2.5)
        let intention = try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: makeMetric(), target: 3
        )
        #expect(intention.derivedMode == .sessionCount)
    }

    @Test
    func derivedValueSumAllowsFractionalTargetsAboveZero() throws {
        expectRejected(.invalidTarget, kind: .derived, mode: .valueSum, metric: makeMetric(), target: 0)
        let intention = try Intention.make(
            title: "4h of walking", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .valueSum, metric: makeMetric(), target: 4.5 * 3600
        )
        #expect(intention.target == 4.5 * 3600)
    }

    @Test
    func binaryMetricsDeriveOnlyBySessionCount() throws {
        expectRejected(
            .binaryMetricRequiresSessionCount,
            kind: .derived, mode: .valueSum, metric: makeMetric(type: .binary), target: 3
        )
        let intention = try Intention.make(
            title: "read scripture", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: makeMetric(type: .binary), target: 3
        )
        #expect(intention.metric?.measurementType == .binary)
    }
}

// MARK: - perDay

extension IntentionInvariantTests {
    @Test
    func perDaySupportsCountedAndSessionCountOnly() throws {
        expectRejected(.reflectiveCarriesMachinery, kind: .reflective, perDay: true)
        expectRejected(.perDayKindUnsupported, kind: .derived, mode: .valueSum, metric: makeMetric(), perDay: true)
        let counted = try Intention.make(
            title: "one act of kindness", kind: .counted, aspiration: makeAspiration(), perDay: true
        )
        #expect(counted.perDay)
        let derived = try Intention.make(
            title: "walk every day", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: makeMetric(), perDay: true
        )
        #expect(derived.perDay)
    }

    @Test
    func perDayCarriesNoTarget() {
        expectRejected(.perDayCarriesTarget, kind: .counted, perDay: true, target: 2)
        expectRejected(
            .perDayCarriesTarget,
            kind: .derived, mode: .sessionCount, metric: makeMetric(), perDay: true, target: 2
        )
    }
}

// MARK: - Tick window

extension IntentionInvariantTests {
    @Test
    func ticksAreConfinedToTheIntentionsWeek() throws {
        let lastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: .now)!
        let intention = try Intention.make(
            title: "3 walks", kind: .counted, aspiration: makeAspiration(), target: 3, createdAt: lastWeek
        )
        let week = intention.weekInterval(calendar: calendar)

        #expect(intention.tick(at: week.start, calendar: calendar))
        #expect(intention.tick(at: week.end.addingTimeInterval(-1), calendar: calendar))
        #expect(!intention.tick(at: week.end, calendar: calendar))
        #expect(!intention.tick(at: week.start.addingTimeInterval(-1), calendar: calendar))
        #expect(!intention.tick(at: .now, calendar: calendar))
        #expect(intention.tickDates.count == 2)
    }
}
