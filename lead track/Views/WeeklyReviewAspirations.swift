import SwiftData
import SwiftUI

/// The aspiration lens of the weekly review — its center stage. Each active
/// aspiration gets one card carrying its week, its intentions, and its
/// action row, and tapping a card drills into the day-by-day distribution.
/// It renders nothing when no aspiration is on stage, so a zero-aspiration
/// review stays byte-identical to before — additive, never a fork. (The
/// resting aspirations close the whole review as one line instead — see
/// `WeeklyReviewView.restingLine`.)
extension WeeklyReviewView {
    @ViewBuilder
    func aspirationSection(_ review: WeeklyReview) -> some View {
        if !review.aspirationWeeks.isEmpty {
            VStack(spacing: 16) {
                sectionBreak("Aspirations")
                ForEach(review.aspirationWeeks) { week in
                    aspirationCard(week, review: review)
                }
            }
            .padding(.horizontal)
            .sheet(item: $settingIntentionFor) { aspiration in
                IntentionFormView(aspiration: aspiration)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $keepingMomentFor) { aspiration in
                MomentFormView(aspiration: aspiration)
            }
        }
    }

    @ViewBuilder
    private func aspirationCard(
        _ week: WeeklyReview.AspirationWeek,
        review: WeeklyReview
    ) -> some View {
        if let aspiration = aspiration(for: week.id) {
            NavigationLink(value: AspirationWeekRoute(aspiration: aspiration, weeksBack: review.weeksBack)) {
                card(week, review: review, aspiration: aspiration)
            }
            .buttonStyle(.plain)
        } else {
            card(week, review: review, aspiration: nil)
        }
    }

    private func card(
        _ week: WeeklyReview.AspirationWeek,
        review: WeeklyReview,
        aspiration: Aspiration?
    ) -> some View {
        AspirationWeekCard(
            week: week,
            closures: review.intentionClosures.filter { $0.aspirationID == week.id },
            onSetIntention: setIntentionAction(for: aspiration, in: review),
            onClosureAction: { action, id in handle(action, closureID: id) },
            onCheckIn: checkInAction(for: aspiration, in: review),
            onKeepMoment: keepMomentAction(for: aspiration, in: review)
        )
    }

    /// The card's "Set an intention" affordance — live review only, and only
    /// when the card maps back to its model.
    private func setIntentionAction(
        for aspiration: Aspiration?,
        in review: WeeklyReview
    ) -> (() -> Void)? {
        guard review.weeksBack == 0, let aspiration else { return nil }
        return { settingIntentionFor = aspiration }
    }

    /// The card's pulse composer — live review only, and only when the card
    /// maps back to its model.
    private func checkInAction(
        for aspiration: Aspiration?,
        in review: WeeklyReview
    ) -> ((AlignmentRating, String?) -> Void)? {
        guard review.weeksBack == 0, let aspiration else { return nil }
        return { rating, note in recordCheckIn(rating, note: note, for: aspiration) }
    }

    /// The card's "Keep a moment" affordance — live review only, and only when
    /// the card maps back to its model. Moment *rows* need no such gate; they
    /// show on browsed weeks too.
    private func keepMomentAction(
        for aspiration: Aspiration?,
        in review: WeeklyReview
    ) -> (() -> Void)? {
        guard review.weeksBack == 0, let aspiration else { return nil }
        return { keepingMomentFor = aspiration }
    }

    /// Upserts the current week's pulse: one row per aspiration per calendar
    /// week, the latest edit winning. Rating taps pass a nil note (leaving
    /// any typed note alone); the note field passes its text.
    private func recordCheckIn(_ rating: AlignmentRating, note: String?, for aspiration: Aspiration) {
        if let existing = AspirationAlignment.currentWeekCheckIn(of: aspiration) {
            existing.ratingRaw = rating.rawValue
            if let note { existing.note = note }
            return
        }
        let checkIn = AspirationCheckIn(
            aspiration: aspiration,
            rating: rating,
            weekStart: Intention.weekStart(containing: .now),
            note: note ?? ""
        )
        modelContext.insert(checkIn)
    }

    private func aspiration(for id: String) -> Aspiration? {
        aspirations.first { ($0.stableID?.uuidString ?? $0.title) == id }
    }
}
