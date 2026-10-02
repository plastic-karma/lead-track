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
            WeekHeaderNavigation(
                weeksBack: $weeksBack,
                reviewedWeeksBack: review.weeksBack,
                formattedRange: review.formattedRange
            )
            WeekHeaderHero(
                goalArcs: goalArcs, heroText: review.heroText,
                heroCaption: review.heroCaption(includeBusiestDay: true), sessionSeries: review.sessionSeries
            )
        }
    }
}

// MARK: - Week navigation

private struct WeekHeaderNavigation: View {
    @Binding var weeksBack: Int
    let reviewedWeeksBack: Int
    let formattedRange: String

    var body: some View {
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
        VStack(spacing: 2) {
            Text(weekTitle)
                .fontWeight(.semibold)
            Text(formattedRange)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
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
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var weekTitle: String {
        switch reviewedWeeksBack {
        case 0: "This Week"
        case 1: "Last Week"
        default: "\(reviewedWeeksBack.formatted()) Weeks Ago"
        }
    }
}

// MARK: - Hero line

private struct WeekHeaderHero: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let goalArcs: [GoalDialArc]
    let heroText: String
    let heroCaption: String
    let sessionSeries: [Double]
    /// The weekly-goal dial (when any weekly goal is set) leads the row, then
    /// the headline number, then the day-by-day pulse — the same circle · number
    /// · flame-graph shape the Today header wears.
    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 16))
        layout {
            if !goalArcs.isEmpty {
                SegmentedGoalDial(arcs: goalArcs)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(heroText)
                    .numeralStyle(.value)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                Text(heroCaption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            miniBars
        }
    }
}

// MARK: - Mini bars

private extension WeekHeaderHero {
    private static let miniBarWidth: CGFloat = 6
    private static let miniBarSpacing: CGFloat = 3

    /// Seven quiet capsules, the busiest day standing solid — `WeekBarsView`
    /// in its compact form (fixed-width bars, no labels), shrunk to a glance
    /// beside the number. The shared view highlights the first peak day,
    /// which is exactly `review.busiestDayOffset`.
    private var miniBars: some View {
        WeekBarsView(
            values: sessionSeries,
            barWidth: Self.miniBarWidth,
            spacing: Self.miniBarSpacing
        )
        .frame(width: miniBarsWidth, height: 26)
        .padding(.bottom, 2)
    }

    /// The strip's intrinsic width — bars plus gaps — since `WeekBarsView`
    /// measures itself with a greedy `GeometryReader`.
    private var miniBarsWidth: CGFloat {
        let count = sessionSeries.count
        return CGFloat(count) * Self.miniBarWidth
            + CGFloat(max(count - 1, 0)) * Self.miniBarSpacing
    }
}

private extension WeekHeaderStrip {
    var goalArcs: [GoalDialArc] {
        goalSegments.map { segment in
            GoalDialArc(
                id: segment.id,
                tint: MetricColor.color(named: segment.colorName),
                fraction: segment.fraction
            )
        }
    }
}
