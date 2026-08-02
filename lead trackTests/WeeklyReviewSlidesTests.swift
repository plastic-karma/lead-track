import Foundation
import Testing
@testable import lead_track

/// The Week tab's slide deck: which sections earn a slide, in what order,
/// and where the pager's selection lands when the deck changes under it.
/// Reviews are hand-assembled — deck logic reads only presence, so each
/// test fills exactly the sections it exercises.
struct WeeklyReviewSlidesTests {
    // MARK: - Fixtures

    /// An empty review to start from; tests fill the sections they need.
    private struct ReviewDraft {
        var weeksBack = 0
        var aspirationWeeks: [WeeklyReview.AspirationWeek] = []
        var intentionClosures: [WeeklyReview.IntentionClosure] = []
        var goalSeasonReviews: [GoalSeason.Review] = []
        var oversubscription: OversubscriptionInsight.CheckIn?
        var intentionAsks: [GoalShortfall.Ask] = []

        func build() -> WeeklyReview {
            WeeklyReview(
                start: Date(timeIntervalSinceReferenceDate: 0),
                end: Date(timeIntervalSinceReferenceDate: 0),
                weeksBack: weeksBack,
                metricWeeks: [],
                quietMetrics: [],
                aspirationWeeks: aspirationWeeks,
                quietAspirations: [],
                intentionClosures: intentionClosures,
                goalSeasonReviews: goalSeasonReviews,
                oversubscription: oversubscription,
                intentionAsks: intentionAsks,
                sessionSeries: []
            )
        }
    }

    private func aspirationWeek(id: String, offersCheckIn: Bool) -> WeeklyReview.AspirationWeek {
        WeeklyReview.AspirationWeek(
            id: id, title: id, icon: "star", colorName: nil,
            totals: [], sessionCount: 0, activeDays: 0, dailySeries: [],
            intentions: [], moments: [], offersCheckIn: offersCheckIn, narrowing: nil
        )
    }

    private var closure: WeeklyReview.IntentionClosure {
        WeeklyReview.IntentionClosure(
            id: "i1", aspirationID: "a1", title: "Read daily", kind: .counted,
            perDay: true, progressText: nil, sourceRemoved: false, promotion: nil
        )
    }

    private var seasonReview: GoalSeason.Review {
        GoalSeason.Review(
            id: "m1", name: "Reading", icon: "book", colorName: nil,
            goalText: "30m / day", seasonNote: "", aspirationTitles: [], phase: .due
        )
    }

    private var ask: GoalShortfall.Ask {
        GoalShortfall.Ask(id: "m1", name: "Reading", icon: "book", colorName: nil, goalDays: 6, missedDays: 4)
    }

    private var load: OversubscriptionInsight.CheckIn {
        OversubscriptionInsight.CheckIn(goalCount: 4, missedDays: 5, activeDays: 6)
    }

    // MARK: - Deck assembly

    @Test
    func emptyWeekStillCloses() {
        let deck = ReviewDraft().build().slides(context: .init())

        #expect(deck == [.done])
    }

    @Test
    func fullDeckReadsInScrollOrder() {
        var draft = ReviewDraft()
        draft.aspirationWeeks = [aspirationWeek(id: "a1", offersCheckIn: true)]
        draft.intentionClosures = [closure]
        draft.goalSeasonReviews = [seasonReview]
        draft.oversubscription = load
        draft.intentionAsks = [ask]
        let context = WeeklyReview.SlideContext(hasMetricGroups: true, hasAspirations: true)

        let deck = draft.build().slides(context: context)

        #expect(deck == [
            .effort, .moments, .intentionsToClose, .intentionsToSet,
            .checkIn, .oversubscription, .goalSeasons, .done
        ])
    }

    @Test
    func effortAndMomentsFollowTheViewsPresence() {
        let review = ReviewDraft().build()

        let bare = review.slides(context: .init())
        let grouped = review.slides(context: .init(hasMetricGroups: true, hasAspirations: true))

        #expect(!bare.contains(.effort))
        #expect(!bare.contains(.moments))
        #expect(grouped.starts(with: [.effort, .moments]))
    }

    @Test
    func browsedWeeksDropTheLiveOnlySlides() {
        var draft = ReviewDraft()
        draft.weeksBack = 1
        draft.aspirationWeeks = [aspirationWeek(id: "a1", offersCheckIn: true)]
        let context = WeeklyReview.SlideContext(hasMetricGroups: true, hasAspirations: true)

        let deck = draft.build().slides(context: context)

        // Moments and the pulse are live-review affordances; the builder
        // already empties the other live-only sections for browsed weeks.
        #expect(deck == [.effort, .done])
    }

    @Test
    func dismissalsRemoveTheirSlides() {
        var draft = ReviewDraft()
        draft.aspirationWeeks = [aspirationWeek(id: "a1", offersCheckIn: true)]
        draft.oversubscription = load
        draft.intentionAsks = [ask]
        var context = WeeklyReview.SlideContext()
        context.checkInDismissed = true
        context.oversubscriptionDismissed = true
        context.intentionAsksDismissed = true

        let deck = draft.build().slides(context: context)

        #expect(deck == [.done])
    }

    @Test
    func answeredPulseHoldsItsSeatForTheVisit() {
        var draft = ReviewDraft()
        draft.aspirationWeeks = [aspirationWeek(id: "a1", offersCheckIn: false)]
        var context = WeeklyReview.SlideContext()

        let closed = draft.build().slides(context: context)
        context.pulsedAspirations = ["a1"]
        let held = draft.build().slides(context: context)

        #expect(!closed.contains(.checkIn))
        #expect(held.contains(.checkIn))
    }

    @Test
    func openCheckInsUnionsOpenAndPulsed() {
        var draft = ReviewDraft()
        draft.aspirationWeeks = [
            aspirationWeek(id: "open", offersCheckIn: true),
            aspirationWeek(id: "answered", offersCheckIn: false),
            aspirationWeek(id: "skipped", offersCheckIn: false)
        ]

        let rows = draft.build().openCheckIns(pulsed: ["answered"])

        #expect(rows.map(\.id) == ["open", "answered"])
    }

    // MARK: - Selection repair

    @Test
    func survivingSelectionStays() {
        let repaired = WeekSlide.repairedSelection(
            .checkIn,
            previous: [.effort, .checkIn, .done],
            current: [.checkIn, .done]
        )

        #expect(repaired == .checkIn)
    }

    @Test
    func dismissedSlideAdvancesToItsNeighbor() {
        let repaired = WeekSlide.repairedSelection(
            .checkIn,
            previous: [.effort, .checkIn, .oversubscription, .done],
            current: [.effort, .oversubscription, .done]
        )

        #expect(repaired == .oversubscription)
    }

    @Test
    func trailingRemovalClampsToTheDeckEnd() {
        let repaired = WeekSlide.repairedSelection(
            .goalSeasons,
            previous: [.goalSeasons, .done],
            current: [.done]
        )

        #expect(repaired == .done)
    }

    @Test
    func unknownSelectionFallsToTheFirstSlide() {
        let repaired = WeekSlide.repairedSelection(
            .moments,
            previous: [],
            current: [.effort, .done]
        )

        #expect(repaired == .effort)
    }
}
