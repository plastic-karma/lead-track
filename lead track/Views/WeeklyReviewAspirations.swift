import SwiftData
import SwiftUI

/// The aspiration lens layer of the weekly review, prepended above the metric
/// pager. It renders nothing when no aspirations exist, so a zero-aspiration
/// review stays byte-identical to before — additive, never a fork.
extension WeeklyReviewView {
    @ViewBuilder
    func aspirationSection(_ review: WeeklyReview) -> some View {
        if !review.aspirationWeeks.isEmpty || !review.quietAspirations.isEmpty {
            VStack(spacing: 12) {
                Text("Aspirations")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(review.aspirationWeeks) { week in
                    aspirationCard(week, weekStart: review.start)
                }
                quietAspirationsCard(review.quietAspirations)
            }
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private func aspirationCard(
        _ week: WeeklyReview.AspirationWeek,
        weekStart: Date
    ) -> some View {
        if let aspiration = aspiration(for: week.id) {
            NavigationLink(value: aspiration) {
                AspirationWeekCard(week: week, weekStart: weekStart)
            }
            .buttonStyle(.plain)
        } else {
            AspirationWeekCard(week: week, weekStart: weekStart)
        }
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
