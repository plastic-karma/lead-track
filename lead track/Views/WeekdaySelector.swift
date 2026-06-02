import SwiftUI

/// A row of weekday circles for marking daily-goal rest days. Filled = goal day,
/// dimmed = excluded rest day. At least one goal day always remains.
struct WeekdaySelector: View {
    @Binding var excludedWeekdays: Set<Int>
    @ScaledMetric(relativeTo: .subheadline) private var diameter: CGFloat = 38

    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 6) {
            ForEach(orderedWeekdays, id: \.self) { weekday in
                dayButton(weekday)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Button

extension WeekdaySelector {
    private func dayButton(_ weekday: Int) -> some View {
        let isGoalDay = !excludedWeekdays.contains(weekday)
        return Button {
            toggle(weekday)
        } label: {
            Text(symbol(for: weekday))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isGoalDay ? Color.white : Color.secondary)
                .frame(width: diameter, height: diameter)
                .background(isGoalDay ? Color.accentColor : Color(.systemGray5))
                .clipShape(Circle())
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fullName(for: weekday))
        .accessibilityValue(isGoalDay ? "Goal day" : "Rest day")
    }
}

// MARK: - Helpers

extension WeekdaySelector {
    private var orderedWeekdays: [Int] {
        let first = calendar.firstWeekday
        return (0 ..< 7).map { ((first - 1 + $0) % 7) + 1 }
    }

    private func toggle(_ weekday: Int) {
        if excludedWeekdays.contains(weekday) {
            excludedWeekdays.remove(weekday)
        } else if excludedWeekdays.count < 6 {
            excludedWeekdays.insert(weekday)
        }
    }

    private func symbol(for weekday: Int) -> String {
        calendar.veryShortWeekdaySymbols[weekday - 1]
    }

    private func fullName(for weekday: Int) -> String {
        calendar.weekdaySymbols[weekday - 1]
    }
}
