import SwiftUI

/// The review's opening card: the date range, the week's headline number,
/// and a sessions-per-day pulse with the busiest day called out. The pulse
/// counts sessions rather than time so duration and count metrics read on
/// one scale.
struct WeekOverviewCard: View {
    let review: WeeklyReview

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            rangeRow
            heroValue
            WeekBarsView(
                values: review.sessionSeries,
                labels: WeekBarsView.weekdayLabels(
                    from: review.start, count: WeeklyReview.periodDays
                )
            )
            .frame(height: 64)
            busiestDayRow
        }
        .cardSurface()
    }
}

// MARK: - Pieces

extension WeekOverviewCard {
    private var rangeRow: some View {
        Text(formattedRange)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private var formattedRange: String {
        "\(review.start.formatted(.dateTime.month().day()))"
            + " — \(review.end.formatted(.dateTime.month().day()))"
    }

    /// Total time leads when any duration metric logged time; otherwise the
    /// session count carries the week.
    private var heroValue: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(heroText)
                .numeralStyle(.value)
            Text(heroCaption)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var heroText: String {
        review.totalDuration > 0
            ? DurationFormatter.format(review.totalDuration)
            : "\(review.sessionCount)"
    }

    private var heroCaption: String {
        let days = "\(review.activeDays) of \(WeeklyReview.periodDays) days active"
        return review.totalDuration > 0
            ? "\(review.sessionCount) sessions · \(days)"
            : "sessions · \(days)"
    }

    @ViewBuilder
    private var busiestDayRow: some View {
        if let offset = review.busiestDayOffset {
            HStack(spacing: 8) {
                Image(systemName: "trophy")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(busiestDayText(offset: offset))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func busiestDayText(offset: Int) -> String {
        let weekday = review.day(at: offset)
            .formatted(.dateTime.weekday(.wide))
        let sessions = Int(review.sessionSeries[offset])
        return "Busiest day \(weekday) · \(sessions) sessions"
    }
}
