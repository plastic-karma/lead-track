import Foundation
import SwiftData

@Model
final class Metric {
    #Unique<Metric>([\.stableID])
    var stableID: UUID?
    var name: String
    var measurementType: MeasurementType
    var unit: String?
    var icon: String?
    var createdAt: Date
    var dailyGoal: TimeInterval?
    var weeklyGoal: TimeInterval?
    var reminderTime: Date?
    var streakAlertTime: Date?
    var excludedWeekdays: [Int] = []

    @Relationship(deleteRule: .cascade, inverse: \Project.metric)
    var projects: [Project] = []

    @Relationship(deleteRule: .cascade, inverse: \Session.metric)
    var sessions: [Session] = []

    init(
        name: String,
        measurementType: MeasurementType = .duration,
        unit: String? = nil,
        icon: String? = nil,
        createdAt: Date = .now
    ) {
        stableID = UUID()
        self.name = name
        self.measurementType = measurementType
        self.unit = unit
        self.icon = icon
        self.createdAt = createdAt
    }
}

// MARK: - Default Project

extension Metric {
    /// The active project that new recordings are auto-assigned to, if any.
    /// At most one active project per metric can be the default.
    var defaultProject: Project? {
        projects.first { $0.isDefault && $0.status == .active }
    }
}

// MARK: - Daily Goal Schedule

extension Metric {
    /// Weekday numbers (1 = Sunday ... 7 = Saturday) excluded from the daily goal.
    var excludedWeekdaySet: Set<Int> {
        Set(excludedWeekdays)
    }

    /// Whether the daily goal applies on the given date's weekday.
    func isGoalDay(on date: Date, calendar: Calendar = .current) -> Bool {
        !excludedWeekdays.contains(calendar.component(.weekday, from: date))
    }
}
