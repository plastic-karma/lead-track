import SwiftData
import SwiftUI

/// The aspiration lens of the weekly review — its center stage. Each active
/// aspiration gets one card carrying its week and its intentions, and tapping
/// a card drills into the day-by-day distribution. It renders nothing when no
/// aspirations exist, so a zero-aspiration review stays byte-identical to
/// before — additive, never a fork.
extension WeeklyReviewView {
    @ViewBuilder
    func aspirationSection(_ review: WeeklyReview) -> some View {
        if !review.aspirationWeeks.isEmpty || !review.quietAspirations.isEmpty {
            VStack(spacing: 12) {
                sectionBreak("Aspirations")
                ForEach(review.aspirationWeeks) { week in
                    aspirationCard(week, review: review)
                }
                quietAspirationsCard(review.quietAspirations)
            }
            .padding(.horizontal)
            .sheet(item: $settingIntentionFor) { aspiration in
                IntentionFormView(aspiration: aspiration)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $promotionGoal) { route in
                GoalSettingsView(metric: route.metric, prefillWeeklyGoal: route.prefillWeekly)
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
            onClosureAction: { action, id in handle(action, closureID: id) }
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

    @ViewBuilder
    private func quietAspirationsCard(
        _ quiet: [WeeklyReview.QuietAspiration]
    ) -> some View {
        if !quiet.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resting this week")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(quiet) { aspiration in
                    quietAspirationRow(aspiration)
                }
            }
            .cardSurface()
        }
    }

    @ViewBuilder
    private func quietAspirationRow(
        _ quiet: WeeklyReview.QuietAspiration
    ) -> some View {
        if let aspiration = aspiration(for: quiet.id) {
            NavigationLink(value: aspiration) {
                quietAspirationContent(quiet)
            }
            .buttonStyle(.plain)
        } else {
            quietAspirationContent(quiet)
        }
    }

    private func quietAspirationContent(
        _ quiet: WeeklyReview.QuietAspiration
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: quiet.icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(quiet.title)
                .font(.subheadline)
            Spacer()
            Text(quiet.lifetimeSummary.isEmpty ? "no effort yet" : quiet.lifetimeSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }

    private func aspiration(for id: String) -> Aspiration? {
        aspirations.first { ($0.stableID?.uuidString ?? $0.title) == id }
    }
}
