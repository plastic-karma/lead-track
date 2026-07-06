import SwiftUI

/// The review's opening breath, folded into the screen instead of boxed in a
/// card: chevrons for browsing weeks around the week's title, the headline
/// number with the whole week's story in one caption line, and a small
/// sessions-per-day pulse at the right where the busiest day stands solid.
/// The pulse counts sessions rather than time so duration and count metrics
/// read on one scale.
struct WeekHeaderStrip: View {
    let review: WeeklyReview
    @Binding var weeksBack: Int

    var body: some View {
        VStack(spacing: 10) {
            navigationRow
            heroRow
        }
    }
}

// MARK: - Week navigation

extension WeekHeaderStrip {
    private var navigationRow: some View {
        HStack(spacing: 10) {
            chevron("chevron.left", label: "Earlier week") {
                weeksBack += 1
            }
            Spacer()
            titleLine
            Spacer()
            chevron("chevron.right", label: "Later week") {
                weeksBack -= 1
            }
            .disabled(weeksBack == 0)
            .opacity(weeksBack == 0 ? 0.4 : 1)
        }
    }

    private var titleLine: some View {
        (
            Text(weekTitle).fontWeight(.semibold)
                + Text(" · \(formattedRange)").foregroundStyle(.secondary)
        )
        .font(.subheadline)
        .lineLimit(1)
    }

    private func chevron(
        _ symbol: String,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.footnote.weight(.semibold))
                .frame(width: 28, height: 28)
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
}

// MARK: - Hero line

extension WeekHeaderStrip {
    /// Total time leads when any duration metric logged time; otherwise the
    /// session count carries the week.
    private var heroRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(heroText)
                    .numeralStyle(.value)
                Text(heroCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            miniBars
        }
    }

    private var heroText: String {
        review.totalDuration > 0
            ? DurationFormatter.format(review.totalDuration)
            : ValueFormatter.sessions(review.sessionCount)
    }

    /// The week's story in one breath: sessions (unless they lead above),
    /// days active, and the busiest day when one won.
    private var heroCaption: String {
        var parts: [String] = []
        if review.totalDuration > 0 {
            parts.append(ValueFormatter.sessions(review.sessionCount))
        }
        parts.append("\(review.activeDays) of \(WeeklyReview.periodDays) days")
        if let offset = review.busiestDayOffset {
            let weekday = review.day(at: offset).formatted(.dateTime.weekday(.abbreviated))
            parts.append("busiest \(weekday)")
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Mini bars

extension WeekHeaderStrip {
    /// Seven quiet capsules, the busiest day standing solid — the pulse the
    /// overview card used to chart, shrunk to a glance beside the number.
    private var miniBars: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(review.sessionSeries.indices, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor.opacity(index == review.busiestDayOffset ? 1 : 0.3))
                    .frame(width: 6, height: barHeight(at: index))
            }
        }
        .padding(.bottom, 2)
        .accessibilityHidden(true)
    }

    private func barHeight(at index: Int) -> CGFloat {
        let peak = max(review.sessionSeries.max() ?? 0, 1)
        return max(26 * review.sessionSeries[index] / peak, 2)
    }
}
