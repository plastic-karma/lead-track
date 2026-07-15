import Foundation

/// The goal-settings form's save semantics as a plain value, so the subtle
/// rules the sheet encodes run in the overlay test suite instead of
/// shipping untested inside a SwiftUI view: seasons re-stamp only when the
/// target amounts change (never on a reminder-only edit), an unseasoned
/// legacy goal acquires its season on the first edit, flipping a binary
/// habit's expectation retires or restarts it, and rest days clear with the
/// daily goal. The view stays a thin binding layer that builds one of these
/// and calls `apply(to:)`.
struct GoalSettingsDraft {
    var hasDailyGoal = false
    var dailyGoalValue = 0.0
    var hasWeeklyGoal = false
    var weeklyGoalValue = 0.0
    var excludedWeekdays: Set<Int> = []
    var expectsDaily = true
    var seasonWeeks = 6
    var seasonNote = ""

    /// Non-positive goals would read as permanently met (`GoalSummary`
    /// treats any non-nil goal as an active target), so Save must disable.
    func isValid(for type: MeasurementType) -> Bool {
        guard type.tracksQuantity else { return true }
        return (!hasDailyGoal || dailyGoalValue > 0)
            && (!hasWeeklyGoal || weeklyGoalValue > 0)
    }

    func apply(to metric: Metric, now: Date = .now) {
        let change = applyTarget(to: metric, now: now)
        applySeason(change, to: metric, now: now)
    }
}

// MARK: - Target & Season Rules

extension GoalSettingsDraft {
    /// What a save changed about the metric's target, for the season rule.
    private struct GoalChange {
        let hasTarget: Bool
        let changed: Bool
    }

    private func applyTarget(to metric: Metric, now: Date) -> GoalChange {
        guard metric.measurementType.tracksQuantity else {
            return applyBinaryExpectation(to: metric, now: now)
        }
        let previousDaily = metric.dailyGoal
        let previousWeekly = metric.weeklyGoal
        metric.dailyGoal = hasDailyGoal
            ? GoalUnit.daily(metric.measurementType).stored(fromDisplay: dailyGoalValue)
            : nil
        metric.excludedWeekdays = hasDailyGoal ? excludedWeekdays.sorted() : []
        metric.weeklyGoal = hasWeeklyGoal
            ? GoalUnit.weekly(metric.measurementType).stored(fromDisplay: weeklyGoalValue)
            : nil
        return GoalChange(
            hasTarget: metric.dailyGoal != nil || metric.weeklyGoal != nil,
            changed: metric.dailyGoal != previousDaily || metric.weeklyGoal != previousWeekly
        )
    }

    /// A binary habit's target is the show-up expectation itself: switching
    /// it off releases it (the card and history stay), switching it back on
    /// is a new experiment and stamps a fresh season.
    private func applyBinaryExpectation(to metric: Metric, now: Date) -> GoalChange {
        metric.dailyGoal = nil
        metric.weeklyGoal = nil
        metric.excludedWeekdays = excludedWeekdays.sorted()
        let wasExpected = metric.binaryGoalRetiredAt == nil
        if expectsDaily != wasExpected {
            metric.binaryGoalRetiredAt = expectsDaily ? nil : now
        }
        return GoalChange(hasTarget: expectsDaily, changed: expectsDaily != wasExpected)
    }

    /// Seasons ride every save: a target present keeps (or starts) its
    /// season — so unseasoned legacy goals acquire one here, on their first
    /// edit — and no target ends it. Only a target change re-stamps the
    /// start; reminder-only edits never reset the clock.
    private func applySeason(_ change: GoalChange, to metric: Metric, now: Date) {
        guard change.hasTarget else {
            GoalSeason.clearSeason(of: metric)
            return
        }
        metric.goalSeasonWeeks = seasonWeeks
        metric.goalSeasonNote = seasonNote.trimmingCharacters(in: .whitespacesAndNewlines)
        GoalSeason.stampOnSave(metric, amountsChanged: change.changed, at: now)
    }
}
