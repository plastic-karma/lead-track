import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The intention layer of the weekly review: the closure list is the most
/// recently completed week only, assembly stays additive (zero intentions ⇒
/// the review is exactly what it was), and deletion degrades the way the
/// relationships promise.
struct IntentionReviewTests {
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

    private func makeAspiration(_ title: String = "Vitality") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric() -> Metric {
        let metric = Metric(name: "Walking")
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeCounted(
        aspiration: Aspiration? = nil,
        createdAt: Date,
        target: Double = 3
    ) throws -> Intention {
        let intention = try Intention.make(
            title: "3 long walks", kind: .counted, aspiration: aspiration ?? makeAspiration(),
            target: target, createdAt: createdAt, calendar: calendar
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    private func closures(of intentions: [Intention], weeksBack: Int = 0) -> [WeeklyReview.IntentionClosure] {
        WeeklyReview.intentionClosures(from: intentions, weeksBack: weeksBack, calendar: calendar)
    }
}

// MARK: - Additivity

extension IntentionReviewTests {
    @Test
    func zeroIntentionsLeaveTheReviewExactlyAsItWas() {
        let metric = makeMetric()
        let session = Session(metric: metric, startedAt: .now, endedAt: .now)
        #if canImport(SwiftData)
        context.insert(session)
        #else
        metric.sessions.append(session)
        #endif
        let aspiration = makeAspiration()
        aspiration.metrics.append(metric)

        let before = WeeklyReview.build(metrics: [metric], aspirations: [aspiration])
        let after = WeeklyReview.build(metrics: [metric], aspirations: [aspiration], intentions: [])

        #expect(after.intentionClosures.isEmpty)
        #expect(after.start == before.start)
        #expect(after.sessionSeries == before.sessionSeries)
        #expect(after.metricWeeks.map(\.id) == before.metricWeeks.map(\.id))
        #expect(after.aspirationWeeks.map(\.id) == before.aspirationWeeks.map(\.id))
        #expect(after.quietMetrics.map(\.id) == before.quietMetrics.map(\.id))
        #expect(after.quietAspirations.map(\.id) == before.quietAspirations.map(\.id))
    }
}

// MARK: - The closure list

extension IntentionReviewTests {
    @Test
    func onlyLastWeeksOpenIntentionsAwaitClosure() throws {
        let thisWeek = try makeCounted(createdAt: .now)
        let lastWeek = try makeCounted(createdAt: weeksAgo(1))
        let closedLastWeek = try makeCounted(createdAt: weeksAgo(1))
        closedLastWeek.letGo(at: weeksAgo(1))
        let frozen = try makeCounted(createdAt: weeksAgo(2))
        let all = [thisWeek, lastWeek, closedLastWeek, frozen]

        let list = closures(of: all)

        #expect(list.count == 1)
        #expect(list.first?.id == lastWeek.stableID?.uuidString)
    }

    @Test
    func browsingEarlierWeeksOffersNoClosures() throws {
        let lastWeek = try makeCounted(createdAt: weeksAgo(1))

        #expect(closures(of: [lastWeek], weeksBack: 1).isEmpty)
    }

    @Test
    func closureShowsTheAccumulationAsFact() throws {
        let intention = try makeCounted(createdAt: weeksAgo(1))
        intention.tick(at: weeksAgo(1), calendar: calendar)
        let aspiration = intention.aspiration

        let closure = try #require(closures(of: [intention]).first)

        #expect(closure.title == "3 long walks")
        #expect(closure.kind == .counted)
        #expect(closure.progressText == "1 of 3")
        #expect(closure.aspirationID == aspiration?.stableID?.uuidString)
        #expect(!closure.sourceRemoved)
    }

    @Test
    func reflectiveClosureCarriesNoNumbers() throws {
        let intention = try Intention.make(
            title: "be present", kind: .reflective, aspiration: makeAspiration(),
            createdAt: weeksAgo(1), calendar: calendar
        )

        let closure = try #require(closures(of: [intention]).first)

        #expect(closure.progressText == nil)
        #expect(closure.promotion == nil)
    }

    @Test
    func thirdConsecutiveWeekEarnsThePromotionOffer() throws {
        let first = try makeCounted(createdAt: weeksAgo(2))
        let second = IntentionRenewal.setAgain(first, now: weeksAgo(1), calendar: calendar)
        let all = [first, second]

        let closure = try #require(closures(of: all).first)

        #expect(closure.id == second.stableID?.uuidString)
        #expect(closure.promotion == .countMetric)
    }

    @Test
    func aShortOrDismissedChainGetsNoOffer() throws {
        let single = try makeCounted(createdAt: weeksAgo(1))
        #expect(try #require(closures(of: [single]).first).promotion == nil)

        let first = try makeCounted(createdAt: weeksAgo(2))
        first.promotionDismissed = true
        let second = IntentionRenewal.setAgain(first, now: weeksAgo(1), calendar: calendar)
        #expect(try #require(closures(of: [first, second]).first).promotion == nil)
    }
}

// MARK: - Degradation

extension IntentionReviewTests {
    @Test
    func strandedDerivedIntentionOffersOnlyLettingGo() throws {
        let intention = try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: makeMetric(), target: 3,
            createdAt: weeksAgo(1), calendar: calendar
        )
        intention.metric = nil

        let closure = try #require(closures(of: [intention]).first)

        #expect(closure.sourceRemoved)
        #expect(closure.progressText == nil)
        #expect(closure.promotion == nil)
    }

    #if canImport(SwiftData)
    @Test
    func deletingTheMetricStrandsTheIntention() throws {
        let metric = makeMetric()
        let intention = try Intention.make(
            title: "3 walks", kind: .derived, aspiration: makeAspiration(),
            derivedMode: .sessionCount, metric: metric, target: 3, calendar: calendar
        )
        context.insert(intention)
        try context.save()

        context.delete(metric)
        try context.save()

        #expect(intention.metric == nil)
        #expect(intention.isSourceRemoved)
    }

    @Test
    func deletingTheAspirationCascadesToItsIntentions() throws {
        let aspiration = makeAspiration()
        let intention = try makeCounted(aspiration: aspiration, createdAt: .now)
        _ = intention
        try context.save()

        context.delete(aspiration)
        try context.save()

        let remaining = try context.fetch(FetchDescriptor<Intention>())
        #expect(remaining.isEmpty)
    }
    #endif
}
