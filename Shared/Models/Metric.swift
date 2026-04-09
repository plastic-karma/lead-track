import Foundation
import SwiftData

@Model
final class Metric {
    #Unique<Metric>([\.stableID])
    var stableID: UUID
    var name: String
    var measurementType: MeasurementType
    var unit: String?
    var icon: String?
    var createdAt: Date
    var dailyGoal: TimeInterval?
    var weeklyGoal: TimeInterval?
    var reminderTime: Date?
    var streakAlertTime: Date?

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
