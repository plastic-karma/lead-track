import Foundation

// The complete released schema must remain one auditable snapshot.
// swiftlint:disable file_length

#if canImport(SwiftData)
import SwiftData

// swiftlint:disable type_body_length
/// Frozen copy of the schema shipped after `a76f37a` added aspiration order.
/// Scheduled intention actions did not exist in this version.
enum LeadTrackHistoricalSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Metric.self,
            Project.self,
            Session.self,
            Aspiration.self,
            Principle.self,
            Intention.self,
            AspirationCheckIn.self,
            Moment.self,
            MomentPhoto.self
        ]
    }

    @Model
    final class Metric {
        #if canImport(SwiftData)
        #Unique<Metric>([\.stableID])
        #endif
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
        var countLogStyleRaw: String = CountLogStyle.askAmount.rawValue
        var archivedAt: Date?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Project.metric)
        #endif
        var projects: [Project] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Session.metric)
        #endif
        var sessions: [Session] = []

        var aspirations: [Aspiration] = []
        var intentions: [Intention] = []
        var moments: [Moment] = []

        init(
            name: String,
            measurementType: MeasurementType = .duration,
            unit: String? = nil,
            icon: String? = nil,
            colorName: String? = nil,
            metricDescription: String? = nil,
            createdAt: Date = .now,
            healthSource: HealthDataSource? = nil
        ) {
            stableID = UUID()
            self.name = name
            self.metricDescription = metricDescription
            self.measurementType = measurementType
            self.unit = unit
            self.icon = icon
            self.colorName = colorName
            self.createdAt = createdAt
            healthSourceRaw = healthSource?.rawValue
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

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Session.project)
        #endif
        var sessions: [Session] = []

        var aspirations: [Aspiration] = []
        var moments: [Moment] = []

        init(
            name: String,
            metric: Metric? = nil,
            status: ProjectStatus = .active,
            startedAt: Date = .now,
            finishedAt: Date? = nil
        ) {
            self.name = name
            self.metric = metric
            self.status = status
            self.startedAt = startedAt
            self.finishedAt = finishedAt
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

        init(
            metric: Metric? = nil,
            project: Project? = nil,
            startedAt: Date = .now,
            endedAt: Date? = nil,
            value: Double? = nil,
            countdownDuration: TimeInterval? = nil
        ) {
            self.metric = metric
            self.project = project
            self.startedAt = startedAt
            self.endedAt = endedAt
            self.value = value
            self.countdownDuration = countdownDuration
        }
    }

    @Model
    final class Aspiration {
        #if canImport(SwiftData)
        #Unique<Aspiration>([\.stableID])
        #endif
        var stableID: UUID?
        var title: String
        var detail: String = ""
        var icon: String?
        var colorName: String?

        #if canImport(SwiftData)
        @Attribute(.externalStorage)
        #endif
        var imageData: Data?

        var createdAt: Date
        var displayOrder: Int?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Metric.aspirations)
        #endif
        var metrics: [Metric] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Project.aspirations)
        #endif
        var projects: [Project] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Principle.aspiration)
        #endif
        var principles: [Principle] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Intention.aspiration)
        #endif
        var intentions: [Intention] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \AspirationCheckIn.aspiration)
        #endif
        var checkIns: [AspirationCheckIn] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \Moment.aspiration)
        #endif
        var moments: [Moment] = []

        init(
            title: String,
            detail: String = "",
            icon: String? = nil,
            colorName: String? = nil,
            imageData: Data? = nil,
            createdAt: Date = .now
        ) {
            stableID = UUID()
            self.title = title
            self.detail = detail
            self.icon = icon
            self.colorName = colorName
            self.imageData = imageData
            self.createdAt = createdAt
        }
    }

    @Model
    final class Principle {
        #if canImport(SwiftData)
        #Unique<Principle>([\.stableID])
        #endif
        var stableID: UUID?
        var text: String
        var createdAt: Date
        var aspiration: Aspiration?
        var intentions: [Intention] = []
        var moments: [Moment] = []

        init(text: String, aspiration: Aspiration?, createdAt: Date = .now) {
            stableID = UUID()
            self.text = text
            self.aspiration = aspiration
            self.createdAt = createdAt
        }
    }

    @Model
    final class Intention {
        #if canImport(SwiftData)
        #Unique<Intention>([\.stableID])
        #endif
        var stableID: UUID?
        var title: String
        var kindRaw: String
        var derivedModeRaw: String?
        var perDay: Bool = false
        var target: Double?
        var weekStart: Date
        var tickDates: [Date] = []

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Metric.intentions)
        #endif
        var metric: Metric?

        var aspiration: Aspiration?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Principle.intentions)
        #endif
        var principle: Principle?

        var outcomeRaw: String?
        var closedAt: Date?
        var predecessorID: UUID?
        var promotionDismissed: Bool = false
        var questionText: String?
        var questionWindowStart: Date?
        var questionWindowEnd: Date?
        var createdAt: Date

        init(
            title: String,
            kind: IntentionKind,
            aspiration: Aspiration?,
            derivedMode: DerivedMode? = nil,
            metric: Metric? = nil,
            perDay: Bool = false,
            target: Double? = nil,
            weekStart: Date,
            createdAt: Date = .now
        ) {
            stableID = UUID()
            self.title = title
            kindRaw = kind.rawValue
            self.aspiration = aspiration
            derivedModeRaw = derivedMode?.rawValue
            self.metric = metric
            self.perDay = perDay
            self.target = target
            self.weekStart = weekStart
            self.createdAt = createdAt
        }
    }

    @Model
    final class AspirationCheckIn {
        #if canImport(SwiftData)
        #Unique<AspirationCheckIn>([\.stableID])
        #endif
        var stableID: UUID?
        var weekStart: Date
        var ratingRaw: Int
        var note: String = ""
        var createdAt: Date
        var aspiration: Aspiration?

        init(
            aspiration: Aspiration?,
            rating: AlignmentRating,
            weekStart: Date,
            note: String = "",
            createdAt: Date = .now
        ) {
            stableID = UUID()
            self.aspiration = aspiration
            ratingRaw = rating.rawValue
            self.weekStart = weekStart
            self.note = note
            self.createdAt = createdAt
        }
    }

    @Model
    final class Moment {
        #if canImport(SwiftData)
        #Unique<Moment>([\.stableID])
        #endif
        var stableID: UUID?
        var text: String
        var occurredAt: Date
        var createdAt: Date
        var latitude: Double?
        var longitude: Double?
        var placeName: String = ""
        var aspiration: Aspiration?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Metric.moments)
        #endif
        var metric: Metric?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Project.moments)
        #endif
        var project: Project?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .nullify, inverse: \Principle.moments)
        #endif
        var principle: Principle?

        #if canImport(SwiftData)
        @Relationship(deleteRule: .cascade, inverse: \MomentPhoto.moment)
        #endif
        var photos: [MomentPhoto] = []

        init(
            text: String,
            aspiration: Aspiration?,
            occurredAt: Date = .now,
            metric: Metric? = nil,
            project: Project? = nil,
            latitude: Double? = nil,
            longitude: Double? = nil,
            placeName: String = "",
            createdAt: Date = .now
        ) {
            stableID = UUID()
            self.text = text
            self.aspiration = aspiration
            self.occurredAt = occurredAt
            self.metric = metric
            self.project = project
            self.latitude = latitude
            self.longitude = longitude
            self.placeName = placeName
            self.createdAt = createdAt
        }
    }

    @Model
    final class MomentPhoto {
        #if canImport(SwiftData)
        @Attribute(.externalStorage)
        #endif
        var data: Data
        var sortIndex: Int
        var moment: Moment?

        init(data: Data, sortIndex: Int = 0, moment: Moment? = nil) {
            self.data = data
            self.sortIndex = sortIndex
            self.moment = moment
        }
    }
}
// swiftlint:enable type_body_length
#endif
