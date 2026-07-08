import SwiftUI

/// The goal-settings sheet route, shared by its two callers: a measure-health
/// insight's "Review goal" chip and a goal season's Adjust decision. A weekly
/// prefill seeds the goal picker when one is offered.
struct GoalSettingsRoute: Identifiable {
    let id = UUID()
    let metric: Metric
    let prefillWeekly: Double?
}

/// The goal-seasons block of the weekly review: each due target gets one row
/// framed against the aspirations its metric serves, with the three
/// decisions — renew, adjust, retire — sitting visually equal. Decisions
/// about targets belong with the why-zone, so the block sits below the
/// metric groups. Live review only; ignoring it changes no goal behavior,
/// ever — after the grace weeks the row just wears the factual "past
/// season" tag.
extension WeeklyReviewView {
    @ViewBuilder
    func goalSeasonSection(_ review: WeeklyReview) -> some View {
        if !review.goalSeasonReviews.isEmpty {
            VStack(spacing: 16) {
                sectionBreak("Goal Seasons")
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(review.goalSeasonReviews) { row in
                        seasonRow(row)
                    }
                }
                .cardSurface()
            }
            .padding(.horizontal)
            .confirmationDialog(
                "Retire this goal?",
                isPresented: retireDialogShowing,
                titleVisibility: .visible,
                presenting: retiringSeasonMetric
            ) { metric in
                Button("Retire Goal", role: .destructive) { retire(metric) }
            } message: { _ in
                Text(
                    "The metric keeps tracking, and your streak of showing up "
                        + "continues. Only the target retires."
                )
            }
        }
    }
}

// MARK: - Rows

extension WeeklyReviewView {
    private func seasonRow(_ row: GoalSeason.Review) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: row.icon)
                    .foregroundStyle(MetricColor.color(named: row.colorName))
                    .frame(width: 24)
                Text(row.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                pastSeasonTag(row.phase)
            }
            Text(row.goalText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !row.seasonNote.isEmpty {
                Text("“\(row.seasonNote)”")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Text(servesLine(row))
                .font(.caption2)
                .foregroundStyle(.secondary)
            seasonDecisions(row)
        }
    }

    /// The factual tag once grace has elapsed — never a count of "debt".
    @ViewBuilder
    private func pastSeasonTag(_ phase: GoalSeason.Phase) -> some View {
        if case .pastSeason = phase {
            Text("past season")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.chipFill, in: Capsule())
        }
    }

    /// "Serves no aspiration yet" is itself the gentle nudge — no CTA.
    private func servesLine(_ row: GoalSeason.Review) -> String {
        row.aspirationTitles.isEmpty
            ? "Serves no aspiration yet"
            : "Serves \(row.aspirationTitles.joined(separator: ", "))"
    }

    private func seasonDecisions(_ row: GoalSeason.Review) -> some View {
        HStack(spacing: 8) {
            seasonButton("Renew") { renewSeason(row) }
            seasonButton("Adjust") { adjustSeason(row) }
            seasonButton("Retire") { retiringSeasonMetric = seasonMetric(for: row) }
        }
        .padding(.top, 2)
    }

    private func seasonButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ActionChip(voice: .decision(.accentColor)) {
                Text(label)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Decisions

extension WeeklyReviewView {
    private var retireDialogShowing: Binding<Bool> {
        Binding(
            get: { retiringSeasonMetric != nil },
            set: { if !$0 { retiringSeasonMetric = nil } }
        )
    }

    private func seasonMetric(for row: GoalSeason.Review) -> Metric? {
        metrics.first { $0.stableID?.uuidString == row.id }
    }

    /// Same experiment, next season.
    private func renewSeason(_ row: GoalSeason.Review) {
        guard let metric = seasonMetric(for: row) else { return }
        withAnimation { GoalSeason.renew(metric) }
    }

    /// Opens the shared goal-settings sheet; saving there re-stamps the season.
    private func adjustSeason(_ row: GoalSeason.Review) {
        guard let metric = seasonMetric(for: row) else { return }
        goalSettingsRoute = GoalSettingsRoute(metric: metric, prefillWeekly: nil)
    }

    /// Clears the goals and the season; rest days, reminders, and the
    /// logged-day streak survive untouched (see `GoalSeason.retire`).
    private func retire(_ metric: Metric) {
        withAnimation { GoalSeason.retire(metric) }
    }
}
