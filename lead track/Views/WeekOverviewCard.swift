import SwiftUI

/// The review's opening card: chevrons for browsing weeks around the week's
/// title, the headline number, and a sessions-per-day pulse with the busiest
/// day called out. The pulse counts sessions rather than time so duration
/// and count metrics read on one scale.
struct WeekOverviewCard: View {
    let review: WeeklyReview
    @Binding var weeksBack: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            navigationRow
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
    private var navigationRow: some View {
        HStack {
            chevron("chevron.left", label: "Earlier week") {
                weeksBack += 1
            }
            Spacer()
            VStack(spacing: 2) {
                Text(weekTitle)
                    .font(.subheadline.weight(.semibold))
                Text(formattedRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            chevron("chevron.right", label: "Later week") {
                weeksBack -= 1
            }
            .disabled(weeksBack == 0)
        }
    }

    private func chevron(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.chipFill))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekTitle: String {
        switch review.weeksBack {
        case 0: "This Week"
        case 1: "Last Week"
        default: "\(review.weeksBack) Weeks Ago"
        }
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
            : ValueFormatter.sessions(review.sessionCount)
    }

    private var heroCaption: String {
        let days = "\(review.activeDays) of \(WeeklyReview.periodDays) days active"
        return review.totalDuration > 0
            ? "\(ValueFormatter.sessions(review.sessionCount)) · \(days)"
            : days
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
        return "Busiest day \(weekday) · \(ValueFormatter.sessions(sessions))"
    }
}
