import Foundation
import Testing
@testable import lead_track
#if canImport(SwiftData)
import SwiftData
#endif

/// Moments folded into the aspiration's weekly review card. A kept moment
/// stages an otherwise-quiet aspiration exactly as an intention does; rows
/// window half-open on `occurredAt` and read in chronological order; and —
/// unlike the intention and check-in machinery — they show on browsed weeks
/// too, because a moment row is pure narrative display.
struct MomentWeekTests {
    private let calendar = Calendar.current
    /// One anchor per suite, captured at init: helpers that recomputed
    /// startOfDay(.now) per call could split a test's fixtures and
    /// assertions across a midnight crossing.
    private let anchor = Calendar.current.startOfDay(for: .now)

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
            to: anchor
        )!
    }

    private func makeAspiration(_ title: String = "Grow wiser") -> Aspiration {
        let aspiration = Aspiration(title: title)
        #if canImport(SwiftData)
        context.insert(aspiration)
        #endif
        return aspiration
    }

    @discardableResult
    private func keep(
        _ text: String,
        under aspiration: Aspiration,
        at occurredAt: Date,
        place: String = "",
        photos: Int = 0
    ) -> Moment {
        let moment = Moment(
            text: text, aspiration: aspiration, occurredAt: occurredAt, placeName: place
        )
        for index in 0 ..< photos {
            moment.photos.append(
                MomentPhoto(data: Data([UInt8(index)]), sortIndex: index, moment: moment)
            )
        }
        #if canImport(SwiftData)
        context.insert(moment)
        #endif
        return moment
    }

    private func buildReview(
        of aspiration: Aspiration,
        moments: [Moment],
        weeksBack: Int = 0
    ) -> WeeklyReview {
        WeeklyReview.build(
            metrics: [], aspirations: [aspiration], moments: moments, weeksBack: weeksBack
        )
    }
}

// MARK: - Staging

extension MomentWeekTests {
    @Test
    func keptMomentStagesARestingAspiration() throws {
        let aspiration = makeAspiration()
        let moment = keep("ran the bridge loop without stopping", under: aspiration, at: day(1))

        let review = buildReview(of: aspiration, moments: [moment])

        #expect(review.quietAspirations.isEmpty)
        let week = try #require(review.aspirationWeeks.first)
        #expect(week.totals.isEmpty)
        #expect(week.sessionCount == 0)
        #expect(week.moments.map(\.text) == ["ran the bridge loop without stopping"])
    }

    @Test
    func aspirationWithoutMomentsStaysQuiet() {
        let aspiration = makeAspiration()

        let review = buildReview(of: aspiration, moments: [])

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.count == 1)
    }

    @Test
    func anotherAspirationsMomentStaysOffTheCard() {
        let quiet = makeAspiration("Resting")
        let busy = makeAspiration("Busy")
        let moment = keep("theirs", under: busy, at: day(1))

        let review = WeeklyReview.build(
            metrics: [], aspirations: [quiet, busy], moments: [moment]
        )

        #expect(review.aspirationWeeks.map(\.title) == ["Busy"])
        #expect(review.quietAspirations.map(\.title) == ["Resting"])
    }
}

// MARK: - The window

extension MomentWeekTests {
    @Test
    func momentOutsideTheWindowDoesNotShow() {
        let aspiration = makeAspiration()
        let old = keep("last month's climb", under: aspiration, at: day(40))

        let review = buildReview(of: aspiration, moments: [old])

        #expect(review.aspirationWeeks.isEmpty)
        #expect(review.quietAspirations.count == 1)
    }

    @Test
    func momentsReadChronologically() throws {
        let aspiration = makeAspiration()
        let later = keep("Friday", under: aspiration, at: day(1))
        let earlier = keep("Monday", under: aspiration, at: day(5))

        let week = try #require(
            buildReview(of: aspiration, moments: [later, earlier]).aspirationWeeks.first
        )

        #expect(week.moments.map(\.text) == ["Monday", "Friday"])
    }

    /// The upper bound is exclusive, the lower inclusive — the same half-open
    /// rule sessions window by. `day(6)` is the first midnight of the live
    /// week, so it belongs there, not to the browsed week ending at it.
    @Test
    func windowIsHalfOpenAtTheWeekBoundary() throws {
        let aspiration = makeAspiration()
        let onUpperBound = keep("upper", under: aspiration, at: day(6))
        let onLowerBound = keep("lower", under: aspiration, at: day(13))

        let browsed = buildReview(
            of: aspiration, moments: [onUpperBound, onLowerBound], weeksBack: 1
        )

        let week = try #require(browsed.aspirationWeeks.first)
        #expect(week.moments.map(\.text) == ["lower"])
    }
}

// MARK: - Live and browsed weeks

extension MomentWeekTests {
    /// The mirror of `intentionMachineryStaysOffEarlierWeeks`: a moment is
    /// narrative, not machinery, so it is absent from the live card yet present
    /// when browsing the week it actually happened.
    @Test
    func momentsShowOnBrowsedWeeksNotJustLive() throws {
        let aspiration = makeAspiration()
        let lastWeek = keep("last week's win", under: aspiration, at: day(9))

        let live = buildReview(of: aspiration, moments: [lastWeek], weeksBack: 0)
        #expect(live.aspirationWeeks.isEmpty)
        #expect(live.quietAspirations.count == 1)

        let browsed = buildReview(of: aspiration, moments: [lastWeek], weeksBack: 1)
        let week = try #require(browsed.aspirationWeeks.first)
        #expect(week.moments.map(\.text) == ["last week's win"])
    }
}

// MARK: - Line contents

extension MomentWeekTests {
    @Test
    func momentLineCarriesPlaceAndPhotoFlag() throws {
        let aspiration = makeAspiration()
        let moment = keep("summit", under: aspiration, at: day(1), place: "Mount Tam", photos: 2)

        let week = try #require(buildReview(of: aspiration, moments: [moment]).aspirationWeeks.first)
        let line = try #require(week.moments.first)

        #expect(line.placeName == "Mount Tam")
        #expect(line.hasPhotos)
        #expect(line.occurredAt == day(1))
    }

    @Test
    func momentLineWithoutPhotosReportsNone() throws {
        let aspiration = makeAspiration()
        let moment = keep("quiet note", under: aspiration, at: day(1))

        let week = try #require(buildReview(of: aspiration, moments: [moment]).aspirationWeeks.first)
        let line = try #require(week.moments.first)

        #expect(line.hasPhotos == false)
        #expect(line.placeName.isEmpty)
    }
}
