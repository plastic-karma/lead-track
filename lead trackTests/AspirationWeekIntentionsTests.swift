import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// The intentions folded into an aspiration's review card: open commitments
/// become lines with their factual accumulation, intention activity alone
/// puts an aspiration on stage, and none of the machinery leaks onto
/// earlier weeks.
struct AspirationWeekIntentionsTests {
    private let calendar = Calendar.current

    #if canImport(SwiftData)
    private let context: ModelContext

    init() throws {
        let container = try SharedModelContainer.create(inMemoryOnly: true)
        context = ModelContext(container)
    }
    #endif

    // MARK: - Fixtures

    private func day(_ daysAgo: Int) -> Date {
        calendar.date(
            byAdding: .day, value: -daysAgo,
            to: calendar.startOfDay(for: .now)
        )!
    }

    private func weeksAgo(_ weeks: Int) -> Date {
        calendar.date(byAdding: .weekOfYear, value: -weeks, to: .now)!
    }

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    private func makeCounted(
        aspiration: Aspiration,
        title: String = "3 deep sessions",
        createdAt: Date = .now
    ) throws -> Intention {
        let intention = try Intention.make(
            title: title, kind: .counted, aspiration: aspiration,
            target: 3, createdAt: createdAt, calendar: calendar
        )
        #if canImport(SwiftData)
        context.insert(intention)
        #endif
        return intention
    }

    private func buildReview(
        of aspiration: Aspiration,
        intentions: [Intention],
        weeksBack: Int = 0
    ) -> WeeklyReview {
        WeeklyReview.build(
            metrics: [], aspirations: [aspiration], intentions: intentions, weeksBack: weeksBack
        )
    }
}

// MARK: - Lines on the card

extension AspirationWeekIntentionsTests {
    @Test
    func openIntentionPutsARestingAspirationOnStage() throws {
        let aspiration = makeAspiration()
        let intention = try makeCounted(aspiration: aspiration)
        intention.tick(calendar: calendar)

        let review = buildReview(of: aspiration, intentions: [intention])

        #expect(review.quietAspirations.isEmpty)
        let week = try #require(review.aspirationWeeks.first)
        #expect(week.totals.isEmpty)
        #expect(week.sessionCount == 0)
        #expect(week.intentions.map(\.title) == ["3 deep sessions"])
        #expect(week.intentions.first?.progressText == "1 of 3")
        #expect(week.intentions.first?.progressFraction == 1.0 / 3.0)
    }

    @Test
    func linesKeepCreationOrder() throws {
        let aspiration = makeAspiration()
        let first = try makeCounted(aspiration: aspiration, title: "first", createdAt: day(0))
        let second = try makeCounted(
            aspiration: aspiration, title: "second", createdAt: day(0).addingTimeInterval(60)
        )

        let week = try #require(buildReview(of: aspiration, intentions: [second, first]).aspirationWeeks.first)

        #expect(week.intentions.map(\.title) == ["first", "second"])
    }

    @Test
    func reflectiveLineCarriesNoNumbers() throws {
        let aspiration = makeAspiration()
        let reflective = try Intention.make(
            title: "be curious", kind: .reflective, aspiration: aspiration, calendar: calendar
        )
        #if canImport(SwiftData)
        context.insert(reflective)
        #endif

        let week = try #require(buildReview(of: aspiration, intentions: [reflective]).aspirationWeeks.first)

        #expect(week.intentions.first?.progressText == nil)
        #expect(week.intentions.first?.progressFraction == nil)
    }

    @Test
    func closedIntentionLeavesTheCard() throws {
        let aspiration = makeAspiration()
        let intention = try makeCounted(aspiration: aspiration)
        intention.letGo()

        let review = buildReview(of: aspiration, intentions: [intention])

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.count == 1)
    }
}

// MARK: - Staging

extension AspirationWeekIntentionsTests {
    @Test
    func pendingClosureKeepsTheAspirationOnStage() throws {
        let aspiration = makeAspiration()
        let intention = try makeCounted(aspiration: aspiration, createdAt: weeksAgo(1))

        let review = buildReview(of: aspiration, intentions: [intention])

        let week = try #require(review.aspirationWeeks.first)
        #expect(week.intentions.isEmpty)
        #expect(review.intentionClosures.map(\.aspirationID) == [week.id])
    }

    @Test
    func intentionMachineryStaysOffEarlierWeeks() throws {
        let aspiration = makeAspiration()
        let intention = try makeCounted(aspiration: aspiration)

        let review = buildReview(of: aspiration, intentions: [intention], weeksBack: 1)

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.count == 1)
    }

    @Test
    func anotherAspirationsIntentionChangesNothing() throws {
        let quiet = makeAspiration("Resting")
        let busy = makeAspiration("Busy")
        let intention = try makeCounted(aspiration: busy)

        let review = WeeklyReview.build(
            metrics: [], aspirations: [quiet, busy], intentions: [intention]
        )

        #expect(review.aspirationWeeks.map(\.title) == ["Busy"])
        #expect(review.quietAspirations.map(\.title) == ["Resting"])
    }
}
