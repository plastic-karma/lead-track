import SwiftUI

/// One day of the goal calendar grid, a pure visual of facts the screen
/// resolves: the day number wearing its verdict — a solid disc when every
/// applicable goal was reached, a translucent disc for a partly-reached
/// tally, a thin ring for a goal day that ended unmet — and the day's small
/// figure underneath (the logged value, or "met/total" when tallying).
struct GoalCalendarDayCell: View {
    struct Model {
        let day: Date
        /// Reached-over-applicable for the day: 1 fills the disc, 0 draws
        /// the unmet ring, in-between fills faintly. nil = no goal applied.
        let fraction: Double?
        /// The small figure under the number, when the day has one.
        let detail: String?
        let isToday: Bool
        let isSelected: Bool
        /// Days ahead of today recede.
        let isMuted: Bool
    }

    let model: Model
    /// Identity ink for rings and faint fills.
    let tint: Color
    /// The deeper fill under the white numeral of a fully-met day.
    let fillTint: Color

    var body: some View {
        VStack(spacing: 3) {
            number
            detailLine
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 5)
        .background(selection)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }
}

// MARK: - Pieces

extension GoalCalendarDayCell {
    private var number: some View {
        Text(model.day, format: .dateTime.day())
            .font(.footnote.weight(model.isToday ? .heavy : .medium))
            .monospacedDigit()
            .foregroundStyle(numberColor)
            .frame(width: 30, height: 30)
            .background(numberBackground)
    }

    private var isFullyMet: Bool {
        (model.fraction ?? 0) >= 1
    }

    private var numberColor: Color {
        if isFullyMet { return .white }
        if model.isMuted { return .secondary }
        if model.isToday { return tint }
        return .primary
    }

    @ViewBuilder
    private var numberBackground: some View {
        if let fraction = model.fraction {
            if fraction >= 1 {
                Circle().fill(fillTint)
            } else if fraction > 0 {
                Circle().fill(tint.opacity(0.16 + 0.3 * fraction))
            } else {
                Circle().strokeBorder(tint.opacity(0.5), lineWidth: 1.5)
            }
        }
    }

    /// Always present (a space when the day has no figure), so every row of
    /// cells keeps one height.
    private var detailLine: some View {
        Text(model.detail ?? " ")
            .font(.caption2.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var selection: some View {
        if model.isSelected {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.chipFill)
        }
    }

    private var accessibilityText: String {
        var parts = [model.day.formatted(date: .abbreviated, time: .omitted)]
        if let fraction = model.fraction {
            parts.append(fraction >= 1 ? "goal reached" : "goal not reached")
        }
        if let detail = model.detail {
            parts.append(detail)
        }
        return parts.joined(separator: ", ")
    }
}
