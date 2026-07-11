import Foundation

/// The one statement of when a metric carries a daily target: a binary
/// habit's implicit "do it today" expectation until it is retired; an
/// amount goal for the quantity types. `GoalSummary`, the watch snapshot,
/// and the complications all read the rule from here instead of keeping
/// hand-copies synchronized by comments.
enum DailyTargetRule {
    static func exists(
        measurementType: MeasurementType?,
        binaryGoalRetiredAt: Date?,
        dailyGoal: Double?
    ) -> Bool {
        if measurementType == .binary {
            return binaryGoalRetiredAt == nil
        }
        return dailyGoal != nil
    }
}
