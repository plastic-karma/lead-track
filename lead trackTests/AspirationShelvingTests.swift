import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

struct AspirationShelvingTests {
    private let fixture: ModelFixture

    init() throws {
        fixture = try ModelFixture()
    }

    private func intention(for owner: Aspiration, weeksAgo: Int = 0) throws -> Intention {
        let intention = try Intention.make(
            title: "Make room", kind: .counted, aspiration: owner, target: 3,
            createdAt: fixture.week(weeksAgo), calendar: fixture.calendar
        )
        #if canImport(SwiftData)
        fixture.context.insert(intention)
        #else
        owner.intentions.append(intention)
        #endif
        return intention
    }

    @Test
    func sharedMetricsMoveToNextActiveOwnerThenUnaligned() {
        let first = fixture.makeAspiration("First")
        let second = fixture.makeAspiration("Second")
        first.displayOrder = 0
        second.displayOrder = 1
        let metric = fixture.makeMetric()
        first.metrics.append(metric)
        second.projects.append(fixture.makeProject("Book", of: metric))
        first.archive()
        let owners = [second, first]
        let reassigned = TodayGrouping.groups(metrics: [metric], aspirations: owners)
        #expect(reassigned.groups.first?.aspiration === second)
        #expect(reassigned.groups.flatMap(\.metrics).map(\.stableIdentity) == [metric.stableIdentity])
        #expect(reassigned.unaligned.isEmpty)
        second.archive()
        let unaligned = TodayGrouping.groups(metrics: [metric], aspirations: owners)
        #expect(unaligned.groups.isEmpty)
        #expect(unaligned.unaligned.map(\.stableIdentity) == [metric.stableIdentity])
        first.unarchive()
        let returned = TodayGrouping.groups(metrics: [metric], aspirations: owners)
        #expect(returned.groups.first?.aspiration === first)
    }

    @Test
    func shelvingKeepsCurrentWorkAndOnlyNormalClosureWindow() throws {
        let owner = fixture.makeAspiration()
        let current = try intention(for: owner)
        let previous = try intention(for: owner, weeksAgo: 1)
        let stale = try intention(for: owner, weeksAgo: 2)
        owner.archive()
        let intentions = [stale, current, previous]
        let clusters = TodayGrouping.clusters(
            metrics: [], aspirations: [owner], intentions: intentions,
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(clusters.flatMap(\.intentions).map(\.stableIdentity) == [current.stableIdentity])
        #expect(current.tick(at: fixture.anchor, calendar: fixture.calendar))
        let review = WeeklyReview.build(
            metrics: [], aspirations: [owner], intentions: intentions,
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(review.intentionClosures.map(\.id) == [previous.stableIdentity])
        #expect(review.aspirationWeeks.first?.intentions.map(\.id) == [current.stableIdentity])
        #expect(review.aspirationWeeks.first?.offersCheckIn == false)
        #expect(review.intentionClosures.first?.promotion == nil)
        #expect(stale.isOpen)
        previous.letGo(at: fixture.anchor)
        #expect(previous.outcome == .letGo)
    }

    @Test
    func shelvingHidesFreshAsksWithoutFreezingHistoricalEffort() {
        let owner = fixture.makeAspiration()
        let metric = fixture.makeMetric()
        owner.metrics.append(metric)
        fixture.addDuration(60, to: metric, at: fixture.week(1))
        owner.archive()
        let live = WeeklyReview.build(
            metrics: [metric], aspirations: [owner], now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(live.aspirationWeeks.isEmpty)
        #expect(live.quietAspirations.isEmpty)
        let past = WeeklyReview.build(
            metrics: [metric], aspirations: [owner], weeksBack: 1,
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(past.aspirationWeeks.first?.sessionCount == 1)
        fixture.addDuration(120, to: metric, at: fixture.week(1).addingTimeInterval(3600))
        let detail = WeeklyReview.aspirationWeekDetail(
            for: owner, weeksBack: 1, now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(detail.week.sessionCount == 2)
        #expect(detail.week.totals.first?.value == 180)
    }

    @Test
    func failedShelvingRestoresOnlyItsFieldInBothDirections() throws {
        enum SaveFailure: Error { case rejected }
        let owner = fixture.makeAspiration()
        #expect(throws: SaveFailure.self) {
            try AspirationShelving.setArchived(true, for: owner) {
                owner.detail = "Unrelated pending edit"
                throw SaveFailure.rejected
            }
        }
        #expect(!owner.isArchived)
        #expect(owner.detail == "Unrelated pending edit")
        owner.archive(at: fixture.anchor)
        #expect(throws: SaveFailure.self) {
            try AspirationShelving.setArchived(false, for: owner) {
                owner.title = "Another pending edit"
                throw SaveFailure.rejected
            }
        }
        #expect(owner.archivedAt == fixture.anchor)
        #expect(owner.title == "Another pending edit")
    }

    @Test
    func shelvingRejectsNewCommitmentsUntilBroughtBack() throws {
        let owner = fixture.makeAspiration()
        owner.archive()
        #expect(throws: Intention.ValidationError.aspirationSetAside) {
            try Intention.make(title: "New", kind: .reflective, aspiration: owner)
        }
        owner.unarchive()
        let fresh = try Intention.make(
            title: "New", kind: .reflective, aspiration: owner,
            createdAt: fixture.anchor, calendar: fixture.calendar
        )
        #expect(fresh.isInCurrentWeek(now: fixture.anchor, calendar: fixture.calendar))
    }

    @Test
    func shortfallOnlyAsksUnderAnActiveOwner() {
        let owner = fixture.makeAspiration()
        let other = fixture.makeAspiration("Another why")
        let metric = fixture.makeMetric()
        metric.createdAt = fixture.day(30)
        metric.dailyGoal = 600
        owner.metrics.append(metric)
        owner.archive()
        let quiet = GoalShortfall.asks(
            for: [metric], aspirations: [owner, other],
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(quiet.isEmpty)
        other.metrics.append(metric)
        let shared = GoalShortfall.asks(
            for: [metric], aspirations: [owner, other],
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(shared.map(\.id) == [metric.stableIdentity])
    }

    @Test
    func rejectedRenewalLeavesExistingCommitmentOpen() throws {
        let owner = fixture.makeAspiration()
        let previous = try intention(for: owner, weeksAgo: 1)
        owner.archive()
        #expect(throws: Intention.ValidationError.aspirationSetAside) {
            try IntentionRenewal.setAgain(previous, now: fixture.anchor, calendar: fixture.calendar)
        }
        #expect(previous.isOpen)
        #expect(IntentionRenewal.offer(for: previous) == nil)
        owner.unarchive()
        let renewed = try IntentionRenewal.setAgain(
            previous, now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(!previous.isOpen)
        #expect(renewed.isInCurrentWeek(now: fixture.anchor, calendar: fixture.calendar))
    }
}

extension AspirationShelvingTests {
    @Test
    func shelvedNarrativeRemainsBrowsableInItsOriginalWeek() throws {
        let owner = fixture.makeAspiration()
        let kept = Moment(text: "An unhurried evening", aspiration: owner, occurredAt: fixture.week(1))
        #if canImport(SwiftData)
        fixture.context.insert(kept)
        #else
        owner.moments.append(kept)
        #endif
        fixture.checkIn(owner, weeksAgo: 1, rating: .serving)
        owner.archive()
        let history = try narrativeHistory(of: owner)
        let series = AspirationAlignment.series(from: history.checkIns)
        #expect(try #require(series.first).rating == AlignmentRating.serving.rawValue)
        let past = WeeklyReview.build(
            metrics: [], aspirations: [owner], moments: history.moments,
            weeksBack: 1, now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(past.aspirationWeeks.first?.moments.map(\.id) == [kept.stableIdentity])
        owner.unarchive()
        let live = WeeklyReview.build(
            metrics: [], aspirations: [owner], moments: history.moments,
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(live.aspirationWeeks.isEmpty)
    }

    @Test
    func closureOnlyOwnerStaysReachableWithoutResurrectingStaleWork() throws {
        let owner = fixture.makeAspiration()
        let previous = try intention(for: owner, weeksAgo: 1)
        let stale = try intention(for: owner, weeksAgo: 3)
        owner.archive()
        let review = WeeklyReview.build(
            metrics: [], aspirations: [owner], intentions: [stale, previous],
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(review.aspirationWeeks.map(\.id) == [owner.stableIdentity])
        #expect(review.intentionClosures.map(\.id) == [previous.stableIdentity])
        previous.letGo(at: fixture.anchor)
        owner.unarchive()
        let returned = WeeklyReview.build(
            metrics: [], aspirations: [owner], intentions: [stale, previous],
            now: fixture.anchor, calendar: fixture.calendar
        )
        #expect(returned.intentionClosures.isEmpty)
        #expect(returned.aspirationWeeks.isEmpty)
    }

    private func narrativeHistory(
        of owner: Aspiration
    ) throws -> (moments: [Moment], checkIns: [AspirationCheckIn]) {
        #if canImport(SwiftData)
        try fixture.context.save()
        return try (
            fixture.context.fetch(FetchDescriptor<Moment>()).filter { $0.aspiration === owner },
            fixture.context.fetch(FetchDescriptor<AspirationCheckIn>()).filter { $0.aspiration === owner }
        )
        #else
        return (owner.moments, owner.checkIns)
        #endif
    }
}
