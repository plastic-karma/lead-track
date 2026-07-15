import Foundation

/// The one shared implementation of the daily-goal schedule rule: a goal
/// applies on a date unless that date's weekday (1 = Sunday ... 7 = Saturday)
/// is excluded. `Metric`, `WatchMetricSnapshot`, and the notification planner
/// all resolve rest days through this, so the convention can only change in
/// one place.
enum GoalDayRule {
    static func isGoalDay(
        on date: Date,
        excludedWeekdays: some Collection<Int>,
        calendar: Calendar
    ) -> Bool {
        !excludedWeekdays.contains(calendar.component(.weekday, from: date))
    }
}
