import SwiftData
import SwiftUI

/// The seeded intention-form route an "Intentions to set" row opens: the
/// flagged metric under the aspiration chosen for it (its only one, or the
/// one picked in the dialog). Mirrors `GoalSettingsRoute`.
struct IntentionAskRoute: Identifiable {
    let id = UUID()
    let aspiration: Aspiration
    let metric: Metric
}

/// The set-an-intention block of the weekly review: one row per metric whose
/// daily goal went unmet more than three times across the last week, each
/// stating the week as fact and offering the intention form seeded with that
/// metric. Setting an intention quiets its row on the spot (the ask defers
/// to an open intention on the metric — see `GoalShortfall`); the header's
/// close button or a sideways swipe sends the whole section away until next
/// week via `WeeklyCheckInDismissal`. Live review only, and absent while
/// there is nothing to ask.
extension WeeklyReviewView {
    @ViewBuilder
    func intentionAsksSection(_ review: WeeklyReview) -> some View {
        if !review.intentionAsks.isEmpty,
           !WeeklyCheckInDismissal.isDismissed(storedWeekStart: dismissedIntentionAskWeek)
        {
            SwipeToDismiss(onDismiss: dismissIntentionAsks) {
                asksBody(review.intentionAsks)
            }
        }
    }

    /// The section's content, split out so `SwipeToDismiss` can carry it: a
    /// header that closes the section, the prompt, then one ask row per
    /// metric — and the aspiration-choice dialog for metrics serving several.
    private func asksBody(_ asks: [GoalShortfall.Ask]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            dismissibleSectionHeader("Intentions to set", dismiss: dismissIntentionAsks)
            Text("Would a week-sized intention help where the daily goal went unmet?")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(asks) { ask in
                IntentionAskRow(ask: ask) { offerIntention(for: ask) }
            }
        }
        .padding(.horizontal)
        .confirmationDialog(
            "Under which aspiration?",
            isPresented: askChoiceShowing,
            titleVisibility: .visible,
            presenting: intentionAskMetric
        ) { metric in
            ForEach(intentionAskOwners(of: metric), id: \.stableIdentity) { owner in
                Button(owner.title) {
                    intentionAskRoute = IntentionAskRoute(aspiration: owner, metric: metric)
                }
            }
        }
    }

    /// Hides the asks for the rest of the current calendar week; they return
    /// on their own once the week rolls over (see `WeeklyCheckInDismissal`).
    private func dismissIntentionAsks() {
        withAnimation(.easeOut(duration: 0.2)) {
            dismissedIntentionAskWeek = WeeklyCheckInDismissal.marker(for: .now)
        }
    }
}

// MARK: - Routing

extension WeeklyReviewView {
    /// Routes a row's chip: one owning aspiration goes straight to the
    /// seeded form; several ask which why the week belongs to first.
    private func offerIntention(for ask: GoalShortfall.Ask) {
        guard let metric = metric(for: ask.id) else { return }
        let owners = intentionAskOwners(of: metric)
        if owners.count == 1, let owner = owners.first {
            intentionAskRoute = IntentionAskRoute(aspiration: owner, metric: metric)
        } else if !owners.isEmpty {
            intentionAskMetric = metric
        }
    }

    /// The aspirations an ask's metric serves, in creation order — read
    /// through the forward `Aspiration.metrics` relationship (the plain
    /// back-array on `Metric` never populates; see `GoalSeason.reviews`).
    private func intentionAskOwners(of metric: Metric) -> [Aspiration] {
        aspirations.filter { $0.metrics.contains { $0 === metric } }
    }

    private var askChoiceShowing: Binding<Bool> {
        Binding(
            get: { intentionAskMetric != nil },
            set: { if !$0 { intentionAskMetric = nil } }
        )
    }
}

// MARK: - Ask row

/// One metric's ask: identity, the week as fact, and the single opening —
/// no counts of debt, no judgment copy.
struct IntentionAskRow: View {
    let ask: GoalShortfall.Ask
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: ask.icon)
                .foregroundStyle(MetricColor.color(named: ask.colorName))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(ask.name)
                    .font(.subheadline.weight(.medium))
                Text(ask.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: open) {
                ActionChip(voice: .opening(.accentColor)) {
                    Text("Set Intention")
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}
