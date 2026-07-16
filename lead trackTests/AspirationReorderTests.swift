import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The manual card order behind drag-to-reorder: the canonical
/// `inDisplayOrder` comparator, the first-drag seeding, the reseat
/// arithmetic and rank rewrite (see `AspirationReorder`), and the ordering
/// handoff where one drag retires Today's smart sort for good.
struct AspirationReorderTests {
    private let calendar = Calendar.current
    /// One anchor per suite, captured at init: helpers that recomputed
    /// startOfDay(.now) per call could split a test's fixtures and
    /// assertions across a midnight crossing.
    private let anchor = Calendar.current.startOfDay(for: .now)

    #if canImport(SwiftData)
    /// Relationship arrays only sync through a context on Apple platforms;
    /// the Linux overlay compiles the models as plain classes instead.
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func date(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: anchor
        )!
    }

    private func makeAspiration(_ title: String, daysAgo: Int, rank: Int? = nil) -> Aspiration {
        let aspiration = Aspiration(title: title, createdAt: date(daysAgo))
        aspiration.displayOrder = rank
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeMetric(_ name: String) -> Metric {
        let metric = Metric(name: name)
        #if canImport(SwiftData)
        context.insert(metric)
        #endif
        return metric
    }

    private func makeIntention(_ title: String, aspiration: Aspiration) -> Intention {
        let intention = Intention(
            title: title, kind: .counted, aspiration: aspiration,
            target: 3, weekStart: Intention.weekStart(containing: .now)
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    // MARK: - Canonical order

    @Test
    func neverRankedFallsBackToCreationOrder() {
        let newer = makeAspiration("Newer", daysAgo: 1)
        let older = makeAspiration("Older", daysAgo: 5)

        #expect([newer, older].inDisplayOrder.map(\.title) == ["Older", "Newer"])
        #expect([newer, older].hasManualOrder == false)
    }

    @Test
    func rankedLeadUnrankedRegardlessOfCreation() {
        let ranked = makeAspiration("Ranked", daysAgo: 1, rank: 0)
        let unranked = makeAspiration("Unranked", daysAgo: 5)

        #expect([unranked, ranked].inDisplayOrder.map(\.title) == ["Ranked", "Unranked"])
        #expect([unranked, ranked].hasManualOrder)
    }

    @Test
    func ranksBeatCreationOrder() {
        let first = makeAspiration("First", daysAgo: 1, rank: 0)
        let second = makeAspiration("Second", daysAgo: 5, rank: 1)

        #expect([second, first].inDisplayOrder.map(\.title) == ["First", "Second"])
    }

    // MARK: - Seeding

    @Test
    func seedingFollowsScreenOrderAndKeepsHiddenSlots() {
        let hiddenB = makeAspiration("B", daysAgo: 9)
        let visibleA = makeAspiration("A", daysAgo: 10)
        let visibleC = makeAspiration("C", daysAgo: 8)
        let hiddenD = makeAspiration("D", daysAgo: 7)

        let seeded = AspirationReorder.seeded(
            all: [visibleA, hiddenB, visibleC, hiddenD],
            visibleIDs: [visibleC.stableIdentity, visibleA.stableIdentity]
        )

        #expect(seeded.map(\.title) == ["C", "B", "A", "D"])
    }

    // MARK: - Applied moves

    @Test
    func dragDownLandsJustBelowTarget() {
        let one = makeAspiration("One", daysAgo: 3)
        let two = makeAspiration("Two", daysAgo: 2)
        let three = makeAspiration("Three", daysAgo: 1)
        let all = [one, two, three]

        AspirationReorder.applyMove(
            all: all,
            visibleIDs: all.map(\.stableIdentity),
            draggedID: one.stableIdentity,
            targetID: two.stableIdentity
        )

        #expect(all.inDisplayOrder.map(\.title) == ["Two", "One", "Three"])
        #expect(all.hasManualOrder)
    }

    @Test
    func dragUpLandsJustAboveTarget() {
        let one = makeAspiration("One", daysAgo: 3, rank: 0)
        let two = makeAspiration("Two", daysAgo: 2, rank: 1)
        let three = makeAspiration("Three", daysAgo: 1, rank: 2)
        let all = [one, two, three]

        AspirationReorder.applyMove(
            all: all,
            visibleIDs: all.map(\.stableIdentity),
            draggedID: three.stableIdentity,
            targetID: one.stableIdentity
        )

        #expect(all.inDisplayOrder.map(\.title) == ["Three", "One", "Two"])
    }

    @Test
    func firstDragSeedsFromTheDraggingScreen() {
        let hiddenB = makeAspiration("B", daysAgo: 9)
        let visibleA = makeAspiration("A", daysAgo: 10)
        let visibleC = makeAspiration("C", daysAgo: 8)
        let all = [visibleA, hiddenB, visibleC]

        AspirationReorder.applyMove(
            all: all,
            visibleIDs: [visibleC.stableIdentity, visibleA.stableIdentity],
            draggedID: visibleA.stableIdentity,
            targetID: visibleC.stableIdentity
        )

        #expect(all.inDisplayOrder.map(\.title) == ["A", "C", "B"])
    }

    @Test
    func selfDropsAndUnknownIDsChangeNothing() {
        let one = makeAspiration("One", daysAgo: 2)
        let two = makeAspiration("Two", daysAgo: 1)
        let all = [one, two]
        let ids = all.map(\.stableIdentity)

        AspirationReorder.applyMove(
            all: all, visibleIDs: ids,
            draggedID: one.stableIdentity, targetID: one.stableIdentity
        )
        AspirationReorder.applyMove(
            all: all, visibleIDs: ids,
            draggedID: "unknown", targetID: two.stableIdentity
        )

        #expect(all.hasManualOrder == false)
        #expect(all.inDisplayOrder.map(\.title) == ["One", "Two"])
    }

    // MARK: - The ordering handoff

    @Test
    func manualOrderRetiresTodaySmartSort() {
        let needy = makeAspiration("Needy", daysAgo: 2)
        let resting = makeAspiration("Resting", daysAgo: 1)
        let metric = makeMetric("Reading")
        needy.metrics.append(metric)
        let intention = makeIntention("Show up", aspiration: resting)

        let smart = TodayGrouping.clusters(
            metrics: [metric], aspirations: [needy, resting], intentions: [intention]
        )
        #expect(smart.map(\.aspiration?.title) == ["Needy", "Resting"])

        resting.displayOrder = 0
        needy.displayOrder = 1
        let manual = TodayGrouping.clusters(
            metrics: [metric], aspirations: [needy, resting], intentions: [intention]
        )
        #expect(manual.map(\.aspiration?.title) == ["Resting", "Needy"])
    }

    @Test
    func unalignedClusterStillTrailsUnderManualOrder() {
        let ranked = makeAspiration("Ranked", daysAgo: 2, rank: 0)
        let attached = makeMetric("Reading")
        let loose = makeMetric("Chores")
        ranked.metrics.append(attached)

        let clusters = TodayGrouping.clusters(
            metrics: [attached, loose], aspirations: [ranked], intentions: []
        )

        #expect(clusters.count == 2)
        #expect(clusters.last?.id == AspirationGrouping.unalignedID)
    }

    @Test
    func groupsFollowManualOrder() {
        let second = makeAspiration("Second", daysAgo: 2, rank: 1)
        let first = makeAspiration("First", daysAgo: 1, rank: 0)
        let one = makeMetric("One")
        let two = makeMetric("Two")
        second.metrics.append(one)
        first.metrics.append(two)

        let split = TodayGrouping.groups(metrics: [one, two], aspirations: [second, first])

        #expect(split.groups.map(\.aspiration.title) == ["First", "Second"])
    }
}
