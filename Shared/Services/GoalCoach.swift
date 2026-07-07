import Foundation

/// The one-line nudge under the metric detail's rings: turns a weekly
/// `GoalPace` into the per-day amount that still reaches the goal, phrased by
/// status — "35m/day Fri–Sun reaches the goal", "Keep 30m/day to stay on
/// pace", or the quiet celebration once the goal is in. Rest days never count
/// toward the split, so the suggestion is always achievable on the days the
/// user actually shows up.
struct GoalCoach {
    let pace: GoalPace
    let measurementType: MeasurementType
    var excludedWeekdays: Set<Int> = []
    var asOf: Date = .now
    var calendar: Calendar = .current

    var line: String {
        if pace.status == .achieved {
            return "Goal reached — the rest of the week is a bonus"
        }
        guard !remainingDays.isEmpty else { return closingLine }
        switch pace.status {
        case .onTrack:
            return "Keep \(perDayText)/day to stay on pace"
        case .ahead:
            return "Ahead of pace — \(perDayText)/day \(spanText) finishes it"
        default:
            return "\(perDayText)/day \(spanText) reaches the goal"
        }
    }
}

// MARK: - Remaining Goal Days

extension GoalCoach {
    /// This week's goal days strictly after today — the days the remaining
    /// amount can still be spread across.
    private var remainingDays: [Date] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: asOf)
        else { return [] }
        let today = calendar.startOfDay(for: asOf)
        return (1 ..< 7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: today) }
            .filter { $0 < week.end }
            .filter { !excludedWeekdays.contains(calendar.component(.weekday, from: $0)) }
    }

    /// "on Sun", "Fri–Sun" for a straight run, or "over 3 days" when rest
    /// days break the run up.
    private var spanText: String {
        let days = remainingDays
        guard let first = days.first, let last = days.last else { return "" }
        if days.count == 1 { return "on \(shortName(first))" }
        if isConsecutive { return "\(shortName(first))–\(shortName(last))" }
        return "over \(days.count) days"
    }

    private var isConsecutive: Bool {
        zip(remainingDays, remainingDays.dropFirst()).allSatisfy {
            calendar.dateComponents([.day], from: $0, to: $1).day == 1
        }
    }

    private func shortName(_ day: Date) -> String {
        calendar.shortWeekdaySymbols[calendar.component(.weekday, from: day) - 1]
    }
}

// MARK: - Amounts

extension GoalCoach {
    /// The week with no spreadable days left: point at today while it can
    /// still carry the goal, otherwise just name the gap.
    private var closingLine: String {
        let gap = amountText(roundedUp(remainingAmount))
        let today = calendar.component(.weekday, from: asOf)
        return excludedWeekdays.contains(today)
            ? "\(gap) to go this week"
            : "\(gap) more today reaches the goal"
    }

    private var remainingAmount: Double {
        max(pace.goal - pace.actual, 0)
    }

    private var perDayText: String {
        let days = max(remainingDays.count, 1)
        return amountText(roundedUp(remainingAmount / Double(days)))
    }

    /// Durations round up to the whole minute and counts to the whole unit,
    /// so the suggestion never understates what reaching the goal takes.
    private func roundedUp(_ value: Double) -> Double {
        measurementType == .duration
            ? (value / 60).rounded(.up) * 60
            : value.rounded(.up)
    }

    private func amountText(_ value: Double) -> String {
        measurementType == .duration
            ? DurationFormatter.compact(value)
            : String(Int(value))
    }
}
