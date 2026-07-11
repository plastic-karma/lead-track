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
    /// One arc per metric with a weekly goal, filled by this week's progress —
    /// the Week header's answer to Today's day dial. Empty hides the dial.
    var goalSegments: [WeeklyReview.GoalDialSegment] = []

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
    /// The weekly-goal dial (when any weekly goal is set) leads the row, then
    /// the headline number, then the day-by-day pulse — the same circle · number
    /// · flame-graph shape the Today header wears.
    private var heroRow: some View {
        HStack(alignment: .center, spacing: 16) {
            if !goalArcs.isEmpty {
                SegmentedGoalDial(arcs: goalArcs)
            }
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

    /// The weekly-goal segments mapped to the shared dial's arcs, each wearing
    /// its metric's color.
    private var goalArcs: [GoalDialArc] {
        goalSegments.enumerated().map { index, segment in
            GoalDialArc(
                id: index,
                tint: MetricColor.color(named: segment.colorName),
                fraction: segment.fraction
            )
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
    private static let miniBarWidth: CGFloat = 6
    private static let miniBarSpacing: CGFloat = 3

    /// Seven quiet capsules, the busiest day standing solid — `WeekBarsView`
    /// in its compact form (fixed-width bars, no labels), shrunk to a glance
    /// beside the number. The shared view highlights the first peak day,
    /// which is exactly `review.busiestDayOffset`.
    private var miniBars: some View {
        WeekBarsView(
            values: review.sessionSeries,
            barWidth: Self.miniBarWidth,
            spacing: Self.miniBarSpacing
        )
        .frame(width: miniBarsWidth, height: 26)
        .padding(.bottom, 2)
    }

    /// The strip's intrinsic width — bars plus gaps — since `WeekBarsView`
    /// measures itself with a greedy `GeometryReader`.
    private var miniBarsWidth: CGFloat {
        let count = review.sessionSeries.count
        return CGFloat(count) * Self.miniBarWidth
            + CGFloat(max(count - 1, 0)) * Self.miniBarSpacing
    }
}
