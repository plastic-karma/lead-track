#if canImport(SwiftData)
import Foundation
import SwiftData

/// Released persisted shape at 2e61bd0. Keep this graph independent of live
/// models: even an unchanged parent must reference historical child types.
/// Only persisted properties are retained; initializer behavior is not schema.
enum LeadTrackSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Metric.self, Project.self, Session.self, Aspiration.self,
            Principle.self, Intention.self, AspirationCheckIn.self,
            Moment.self, MomentPhoto.self
        ]
    }
}

extension LeadTrackSchemaV1 {
    @Model
    final class Metric {
        #Unique<Metric>([\.stableID])
        var stableID: UUID?
        var name: String
        var metricDescription: String?
        var measurementType: MeasurementType
        var unit: String?
        var icon: String?
        var colorName: String?
        var createdAt: Date
        var dailyGoal: TimeInterval?
        var weeklyGoal: TimeInterval?
        var reminderTime: Date?
        var streakAlertTime: Date?
        var reminderTimes: [Date] = []
        var reminderRandomStart: Date?
        var reminderRandomEnd: Date?
        var reminderRandomCount: Int = 2
        var reminderUsesRandom: Bool = false
        var excludedWeekdays: [Int] = []
        var healthSourceRaw: String?
        var lastHealthSyncAt: Date?
        var healthExportRaw: String?
        var healthExportEnabledAt: Date?
        var goalSeasonStartedAt: Date?
        var goalSeasonWeeks: Int?
        var goalSeasonNote: String = ""
        var binaryGoalRetiredAt: Date?
        var countLogStyleRaw: String = "askAmount"
        var archivedAt: Date?
        var isFavorite: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \Project.metric)
        var projects: [Project] = []
        @Relationship(deleteRule: .cascade, inverse: \Session.metric)
        var sessions: [Session] = []
        var aspirations: [Aspiration] = []
        var intentions: [Intention] = []
        var moments: [Moment] = []

        init(name: String, measurementType: MeasurementType = .duration, createdAt: Date = .now) {
            stableID = UUID()
            self.name = name
            self.measurementType = measurementType
            self.createdAt = createdAt
        }
    }

    @Model
    final class Project {
        var name: String
        var metric: Metric?
        var status: ProjectStatus
        var startedAt: Date
        var finishedAt: Date?
        var isDefault: Bool = false

        @Relationship(deleteRule: .cascade, inverse: \Session.project)
        var sessions: [Session] = []
        var aspirations: [Aspiration] = []
        var moments: [Moment] = []

        init(name: String, status: ProjectStatus = .active, startedAt: Date = .now) {
            self.name = name
            self.status = status
            self.startedAt = startedAt
        }
    }

    @Model
    final class Session {
        var metric: Metric?
        var project: Project?
        var startedAt: Date
        var endedAt: Date?
        var value: Double?
        var countdownDuration: TimeInterval?
        var healthExportedAt: Date?

        init(startedAt: Date = .now) {
            self.startedAt = startedAt
        }
    }
}
#endif
