import Foundation

/// Goal seasons: every amount goal is an experiment with an end date,
/// deliberately renewed, adjusted, or retired at the Weekly Review instead of
/// living forever — a permanent target is how a measure quietly becomes the
/// point. Pure math over `Metric`'s three season fields, unit-tested on Linux.
///
/// Doctrine (docs/ASPIRATION_STEERING.md): a lapsed season never changes goal
/// behavior — rings, pace, and reminders keep working; it only gains the
/// factual "past season" tag. Unseasoned pre-feature goals are never due;
/// they acquire a season the first time `GoalSettingsView` saves them.
/// Retiring is a first-class positive act, not a failure.
enum GoalSeason {
    static let defaultLengthWeeks = 6
    static let lengthChoices = [4, 6, 8, 12]
    /// Weeks a finished season sits as `.due` before the passive tag applies.
    static let graceWeeks = 2

    enum Phase: Equatable {
        /// No goal, a released binary habit, or an unseasoned (pre-feature)
        /// goal.
        case none
        case active(weeksRemaining: Int)
        /// The season ended within the grace window; the review offers the
        /// renew/adjust/retire decision.
        case due
        /// Grace elapsed. The goal still works in full; surfaces wear the
        /// factual tag and the review keeps offering the same single row —
        /// never stacking, never counting debt.
        case pastSeason(weeksOver: Int)
    }

    static func phase(
        of metric: Metric,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Phase {
        guard hasSeasonedGoal(metric),
              let started = metric.goalSeasonStartedAt,
              let weeks = metric.goalSeasonWeeks,
              let end = calendar.date(byAdding: .day, value: weeks * 7, to: started)
        else { return .none }
        guard now >= end else {
            return .active(weeksRemaining: weeksUntil(end, from: now, calendar: calendar))
        }
        let over = fullWeeks(from: end, to: now, calendar: calendar)
        return over < graceWeeks ? .due : .pastSeason(weeksOver: over)
    }

    /// A binary habit's target is the implicit show-up-today expectation, so
    /// its season runs while that expectation is live; quantity metrics need
    /// an amount goal.
    private static func hasSeasonedGoal(_ metric: Metric) -> Bool {
        if metric.measurementType == .binary {
            return metric.expectsDailyShowUp
        }
        return metric.dailyGoal != nil || metric.weeklyGoal != nil
    }

    /// Weeks left, rounded up, never below one while the season is active.
    private static func weeksUntil(_ end: Date, from now: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: now, to: end).day ?? 0
        return max(1, (days + 6) / 7)
    }

    private static func fullWeeks(from start: Date, to end: Date, calendar: Calendar) -> Int {
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        return max(0, days / 7)
    }
}

// MARK: - Review rows

extension GoalSeason {
    /// One due target's row on the live review, framed by what it serves.
    struct Review: Identifiable, Equatable {
        let id: String
        let name: String
        let icon: String
        let colorName: String?
        /// "30m / day · 5h / week"
        let goalText: String
        let seasonNote: String
        let aspirationTitles: [String]
        let phase: Phase
    }

    /// Review rows for the live review only: metrics whose season is due or
    /// past, each with the titles of the aspirations it serves — read through
    /// the forward `Aspiration.metrics` relationship (the plain back-array on
    /// `Metric` never populates; see `MetricDetailView`).
    static func reviews(
        for metrics: [Metric],
        aspirations: [Aspiration] = [],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [Review] {
        metrics.compactMap { metric in
            let phase = phase(of: metric, now: now, calendar: calendar)
            guard phase.needsReview else { return nil }
            return Review(
                id: metric.stableIdentity,
                name: metric.name,
                icon: metric.displayIcon,
                colorName: metric.colorName,
                goalText: goalText(of: metric),
                seasonNote: metric.goalSeasonNote,
                aspirationTitles: titles(serving: metric, among: aspirations),
                phase: phase
            )
        }
    }

    private static func goalText(of metric: Metric) -> String {
        guard metric.measurementType.tracksQuantity else { return "Show up daily" }
        var parts: [String] = []
        if let daily = metric.dailyGoal {
            parts.append(ValueFormatter.format(daily, type: metric.measurementType, unit: metric.unit) + " / day")
        }
        if let weekly = metric.weeklyGoal {
            parts.append(ValueFormatter.format(weekly, type: metric.measurementType, unit: metric.unit) + " / week")
        }
        return parts.joined(separator: " · ")
    }

    private static func titles(serving metric: Metric, among aspirations: [Aspiration]) -> [String] {
        aspirations
            .sorted { $0.createdAt < $1.createdAt }
            .filter { $0.metrics.contains(where: { $0 === metric }) }
            .map(\.title)
    }
}

extension GoalSeason.Phase {
    /// Whether the live review offers this phase its decision row.
    var needsReview: Bool {
        switch self {
        case .due, .pastSeason: true
        case .none, .active: false
        }
    }
}

// MARK: - Decisions & stamping

extension GoalSeason {
    /// Renew: same experiment, next season — re-stamps the start, keeps the
    /// length and the note.
    static func renew(_ metric: Metric, at date: Date = .now) {
        metric.goalSeasonStartedAt = date
    }

    /// Retire: a first-class ending — clears both goals and the season (for
    /// a binary habit, releases its show-up expectation instead: the card,
    /// logging, and history all stay), and deliberately preserves rest days,
    /// reminders, and streak alerts: the streak is a logged-day streak the
    /// goal amount never entered, so rest days keep protecting it, and
    /// reminders are about showing up, not the target.
    static func retire(_ metric: Metric, at date: Date = .now) {
        if metric.measurementType == .binary {
            metric.binaryGoalRetiredAt = date
        }
        metric.dailyGoal = nil
        metric.weeklyGoal = nil
        clearSeason(of: metric)
    }

    /// Removes the season fields (goals switched off or retired).
    static func clearSeason(of metric: Metric) {
        metric.goalSeasonStartedAt = nil
        metric.goalSeasonWeeks = nil
        metric.goalSeasonNote = ""
    }

    /// The stamp rule on a goal-settings save: a fresh stamp when a goal was
    /// just enabled or an amount changed (a new experiment), kept when only
    /// reminders or the note moved — and started for an unseasoned legacy
    /// goal on its first edit.
    static func stampOnSave(_ metric: Metric, amountsChanged: Bool, at date: Date = .now) {
        if metric.goalSeasonStartedAt == nil || amountsChanged {
            metric.goalSeasonStartedAt = date
        }
    }
}
