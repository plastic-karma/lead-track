import Foundation
import Testing
@testable import lead_track

/// The goal-settings save semantics (see `GoalSettingsDraft`): season
/// stamping, legacy-goal adoption, binary retirement, and rest-day
/// clearing — the rules that used to live untested inside the sheet.
struct GoalSettingsDraftTests {
    private let now = Date(timeIntervalSince1970: 1_750_000_000)

    private func makeMetric(type: MeasurementType = .duration) -> Metric {
        Metric(name: "Reading", measurementType: type)
    }

    private func draft(daily: Double?, weekly: Double? = nil) -> GoalSettingsDraft {
        GoalSettingsDraft(
            hasDailyGoal: daily != nil,
            dailyGoalValue: daily ?? 0,
            hasWeeklyGoal: weekly != nil,
            weeklyGoalValue: weekly ?? 0,
            excludedWeekdays: [1],
            expectsDaily: true,
            seasonWeeks: 6,
            seasonNote: " note "
        )
    }

    @Test
    func reminderOnlyEditKeepsTheSeasonClock() {
        let metric = makeMetric()
        draft(daily: 30).apply(to: metric, now: now)
        let started = metric.goalSeasonStartedAt

        draft(daily: 30).apply(to: metric, now: now.addingTimeInterval(86400))

        #expect(metric.goalSeasonStartedAt == started)
    }

    @Test
    func amountChangeRestampsTheSeason() {
        let metric = makeMetric()
        draft(daily: 30).apply(to: metric, now: now)
        let later = now.addingTimeInterval(7 * 86400)

        draft(daily: 45).apply(to: metric, now: later)

        #expect(metric.dailyGoal == 2700.0)
        #expect(metric.goalSeasonStartedAt == later)
    }

    @Test
    func unseasonedLegacyGoalAcquiresASeasonOnFirstEdit() {
        let metric = makeMetric()
        metric.dailyGoal = 1800

        draft(daily: 30).apply(to: metric, now: now)

        #expect(metric.goalSeasonStartedAt == now)
        #expect(metric.goalSeasonWeeks == 6)
        #expect(metric.goalSeasonNote == "note")
    }

    @Test
    func clearingTargetsEndsTheSeasonAndRestDays() {
        let metric = makeMetric()
        draft(daily: 30).apply(to: metric, now: now)

        draft(daily: nil).apply(to: metric, now: now)

        #expect(metric.dailyGoal == nil)
        #expect(metric.goalSeasonStartedAt == nil)
        #expect(metric.excludedWeekdays.isEmpty)
    }

    @Test
    func binaryExpectationRetiresAndRestarts() {
        let metric = makeMetric(type: .binary)
        var draft = GoalSettingsDraft()
        draft.expectsDaily = false

        draft.apply(to: metric, now: now)
        #expect(metric.binaryGoalRetiredAt == now)
        #expect(metric.goalSeasonStartedAt == nil)

        let later = now.addingTimeInterval(86400)
        draft.expectsDaily = true
        draft.apply(to: metric, now: later)
        #expect(metric.binaryGoalRetiredAt == nil)
        #expect(metric.goalSeasonStartedAt == later)
    }

    @Test
    func nonPositiveGoalsAreInvalid() {
        var invalid = GoalSettingsDraft()
        invalid.hasDailyGoal = true
        invalid.dailyGoalValue = 0
        #expect(!invalid.isValid(for: .duration))
        #expect(invalid.isValid(for: .binary))
    }
}
