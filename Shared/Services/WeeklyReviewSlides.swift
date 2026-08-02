import Foundation

/// One focus of the Week tab's slide deck. The tab pages sideways through
/// these instead of stacking every section into one crowded scroll: each
/// present section is a slide of its own, and `done` always closes the deck
/// as the review's final breath.
enum WeekSlide: String, CaseIterable, Identifiable {
    /// The aspiration-grouped metric cards — the week's effort.
    case effort
    /// The keep-photos-as-moments doorway.
    case moments
    /// Closure decisions for last week's open intentions.
    case intentionsToClose
    /// The set-an-intention asks where daily goals went unmet.
    case intentionsToSet
    /// The weekly alignment pulse per still-open aspiration.
    case checkIn
    /// The oversubscription load check-in.
    case oversubscription
    /// The renew / adjust / retire decisions on due goal seasons.
    case goalSeasons
    /// The closing slide: the review is complete.
    case done

    var id: String {
        rawValue
    }
}

// MARK: - Deck assembly

extension WeeklyReview {
    /// The view-held state a deck depends on beyond the review itself: the
    /// grouped-card and aspiration presence the view computes, the pulses
    /// answered this visit, and the three until-next-week dismissals —
    /// evaluated booleans, so the deck logic stays pure and Linux-testable.
    struct SlideContext {
        var hasMetricGroups = false
        var hasAspirations = false
        /// Aspirations whose pulse was answered this visit; they hold their
        /// seat on the check-in slide so it doesn't vanish mid-typing.
        var pulsedAspirations: Set<String> = []
        var checkInDismissed = false
        var oversubscriptionDismissed = false
        var intentionAsksDismissed = false
    }

    /// The slides this review shows, in the reading order the old scroll
    /// used, each section present exactly when it used to render — and
    /// `done` always last, so even an empty week closes cleanly.
    func slides(context: SlideContext) -> [WeekSlide] {
        let candidates: [(slide: WeekSlide, present: Bool)] = [
            (.effort, context.hasMetricGroups),
            (.moments, weeksBack == 0 && context.hasAspirations),
            (.intentionsToClose, !intentionClosures.isEmpty),
            (.intentionsToSet, !intentionAsks.isEmpty && !context.intentionAsksDismissed),
            (.checkIn, offersCheckInSlide(context)),
            (.oversubscription, oversubscription != nil && !context.oversubscriptionDismissed),
            (.goalSeasons, !goalSeasonReviews.isEmpty),
            (.done, true)
        ]
        return candidates.compactMap { $0.present ? $0.slide : nil }
    }

    /// The rows the check-in slide shows: aspirations still open for the
    /// week's pulse, plus the ones answered this visit so their note field
    /// survives the answer.
    func openCheckIns(pulsed: Set<String>) -> [AspirationWeek] {
        aspirationWeeks.filter { $0.offersCheckIn || pulsed.contains($0.id) }
    }

    private func offersCheckInSlide(_ context: SlideContext) -> Bool {
        weeksBack == 0
            && !context.checkInDismissed
            && !openCheckIns(pulsed: context.pulsedAspirations).isEmpty
    }
}

// MARK: - Selection repair

extension WeekSlide {
    /// Where the pager's selection lands when the deck changes under it: the
    /// same slide when it survived, otherwise the slide now standing at its
    /// old place — so dismissing a slide advances to its neighbor — clamped
    /// to the deck's end. Total: an empty deck (never built; `done` always
    /// closes a real one) falls back to `done`.
    static func repairedSelection(
        _ selection: WeekSlide,
        previous: [WeekSlide],
        current: [WeekSlide]
    ) -> WeekSlide {
        guard !current.contains(selection) else { return selection }
        let oldIndex = previous.firstIndex(of: selection) ?? 0
        let clamped = min(oldIndex, current.count - 1)
        return current.indices.contains(clamped) ? current[clamped] : .done
    }
}
