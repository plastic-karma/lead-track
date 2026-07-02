import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Renewal ("set again"), the predecessor chain, and the promotion offers a
/// chain earns: eligibility at three consecutive weeks, dismissal propagation,
/// and the per-shape mapping onto the app's permanent machinery.
struct IntentionRenewalChainTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func weeksAgo(_ weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -weeks, to: .now)!
    }

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

    private func makeCounted(perDay: Bool = false, createdAt: Date) throws -> Intention {
        try Intention.make(
            title: "3 long walks", kind: .counted, aspiration: makeAspiration(),
            perDay: perDay, target: perDay ? nil : 3, createdAt: createdAt, calendar: calendar
        )
    }

    private func makeDerived(
        mode: DerivedMode = .sessionCount,
        metric: Metric? = nil,
        perDay: Bool = false
    ) throws -> Intention {
        try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: mode, metric: metric ?? makeMetric(), perDay: perDay,
            target: perDay ? nil : 3, createdAt: weeksAgo(1), calendar: calendar
        )
    }
}

// MARK: - Set again

extension IntentionRenewalChainTests {
    @Test
    func setAgainClonesTheCommitmentIntoTheCurrentWeek() throws {
        let source = try makeCounted(createdAt: weeksAgo(1))
        source.tick(at: weeksAgo(1), calendar: calendar)

        let renewed = IntentionRenewal.setAgain(source, calendar: calendar)

        #expect(renewed.title == source.title)
        #expect(renewed.kind == .counted)
        #expect(renewed.target == 3)
        #expect(renewed.aspiration === source.aspiration)
        #expect(renewed.predecessorID == source.stableID)
        #expect(renewed.weekStart == Intention.weekStart(containing: .now, calendar: calendar))
        #expect(renewed.tickDates.isEmpty)
        #expect(renewed.isOpen)
    }

    @Test
    func setAgainClosesTheSourceWithoutAVerdict() throws {
        let source = try makeCounted(createdAt: weeksAgo(1))

        _ = IntentionRenewal.setAgain(source, calendar: calendar)

        #expect(!source.isOpen)
        #expect(source.outcome == nil)
    }

    @Test
    func setAgainCarriesDismissalForward() throws {
        let source = try makeCounted(createdAt: weeksAgo(1))
        source.promotionDismissed = true

        let renewed = IntentionRenewal.setAgain(source, calendar: calendar)

        #expect(renewed.promotionDismissed)
    }
}

// MARK: - Chain length

extension IntentionRenewalChainTests {
    @Test
    func chainLengthWalksThePredecessorLinks() throws {
        let first = try makeCounted(createdAt: weeksAgo(2))
        let second = IntentionRenewal.setAgain(first, now: weeksAgo(1), calendar: calendar)
        let third = IntentionRenewal.setAgain(second, calendar: calendar)
        let all = [first, second, third]

        #expect(IntentionRenewal.chainLength(of: first, among: all) == 1)
        #expect(IntentionRenewal.chainLength(of: second, among: all) == 2)
        #expect(IntentionRenewal.chainLength(of: third, among: all) == 3)
    }

    @Test
    func chainLengthStopsAtAMissingPredecessor() throws {
        let orphan = try makeCounted(createdAt: weeksAgo(1))
        orphan.predecessorID = UUID()

        #expect(IntentionRenewal.chainLength(of: orphan, among: [orphan]) == 1)
    }

    @Test
    func chainLengthSurvivesACorruptCycle() throws {
        let first = try makeCounted(createdAt: weeksAgo(2))
        let second = try makeCounted(createdAt: weeksAgo(1))
        first.predecessorID = second.stableID
        second.predecessorID = first.stableID

        #expect(IntentionRenewal.chainLength(of: first, among: [first, second]) == 2)
    }
}

// MARK: - Promotion eligibility

extension IntentionRenewalChainTests {
    @Test
    func offerAppearsWhenSettingAgainWouldMakeThreeWeeks() throws {
        let first = try makeCounted(createdAt: weeksAgo(2))
        let second = IntentionRenewal.setAgain(first, now: weeksAgo(1), calendar: calendar)
        let all = [first, second]

        #expect(IntentionRenewal.offerOnSetAgain(of: first, among: all) == nil)
        #expect(IntentionRenewal.offerOnSetAgain(of: second, among: all) == .countMetric)
    }

    @Test
    func aDismissedChainIsNeverAskedAgain() throws {
        let first = try makeCounted(createdAt: weeksAgo(2))
        first.promotionDismissed = true
        let second = IntentionRenewal.setAgain(first, now: weeksAgo(1), calendar: calendar)

        #expect(IntentionRenewal.offerOnSetAgain(of: second, among: [first, second]) == nil)
    }
}

// MARK: - Promotion mapping

extension IntentionRenewalChainTests {
    @Test
    func eachShapeMapsToItsOwnPermanentMachinery() throws {
        let sessionWeekly = try makeDerived(mode: .sessionCount)
        let sumWeekly = try makeDerived(mode: .valueSum)
        let perDayDerived = try makeDerived(perDay: true)
        let countedWeekly = try makeCounted(createdAt: weeksAgo(1))
        let countedPerDay = try makeCounted(perDay: true, createdAt: weeksAgo(1))
        let reflective = try Intention.make(title: "be present", kind: .reflective, aspiration: makeAspiration())

        #expect(IntentionRenewal.offer(for: sessionWeekly) == .weeklyGoal)
        #expect(IntentionRenewal.offer(for: sumWeekly) == .weeklyGoal)
        #expect(IntentionRenewal.offer(for: perDayDerived) == .dailyGoal)
        #expect(IntentionRenewal.offer(for: countedWeekly) == .countMetric)
        #expect(IntentionRenewal.offer(for: countedPerDay) == .binaryMetric)
        #expect(IntentionRenewal.offer(for: reflective) == nil)
    }

    @Test
    func aDerivedIntentionWithoutItsMetricHasNothingToPromoteTo() throws {
        let stranded = try makeDerived()
        stranded.metric = nil

        #expect(IntentionRenewal.offer(for: stranded) == nil)
    }
}
