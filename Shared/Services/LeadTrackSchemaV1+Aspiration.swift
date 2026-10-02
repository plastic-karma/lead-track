#if canImport(SwiftData)
import Foundation
import SwiftData

/// Persisted aspiration graph from 2e61bd0; never reference live model classes.
extension LeadTrackSchemaV1 {
    @Model
    final class Aspiration {
        #Unique<Aspiration>([\.stableID])
        var stableID: UUID?
        var title: String
        var detail: String = ""
        var icon: String?
        var colorName: String?
        @Attribute(.externalStorage)
        var imageData: Data?
        var createdAt: Date
        var archivedAt: Date?
        var displayOrder: Int?

        @Relationship(deleteRule: .nullify, inverse: \Metric.aspirations)
        var metrics: [Metric] = []
        @Relationship(deleteRule: .nullify, inverse: \Project.aspirations)
        var projects: [Project] = []
        @Relationship(deleteRule: .cascade, inverse: \Principle.aspiration)
        var principles: [Principle] = []
        @Relationship(deleteRule: .cascade, inverse: \Intention.aspiration)
        var intentions: [Intention] = []
        @Relationship(deleteRule: .cascade, inverse: \AspirationCheckIn.aspiration)
        var checkIns: [AspirationCheckIn] = []
        @Relationship(deleteRule: .cascade, inverse: \Moment.aspiration)
        var moments: [Moment] = []

        init(title: String, createdAt: Date = .now) {
            stableID = UUID()
            self.title = title
            self.createdAt = createdAt
        }
    }

    @Model
    final class Principle {
        #Unique<Principle>([\.stableID])
        var stableID: UUID?
        var text: String
        var createdAt: Date
        var aspiration: Aspiration?
        var intentions: [Intention] = []
        var moments: [Moment] = []

        init(text: String, createdAt: Date = .now) {
            stableID = UUID()
            self.text = text
            self.createdAt = createdAt
        }
    }

    @Model
    final class Intention {
        #Unique<Intention>([\.stableID])
        var stableID: UUID?
        var title: String
        var kindRaw: String
        var derivedModeRaw: String?
        var perDay: Bool = false
        var target: Double?
        var weekStart: Date
        var tickDates: [Date] = []

        @Relationship(deleteRule: .nullify, inverse: \Metric.intentions)
        var metric: Metric?
        var aspiration: Aspiration?
        @Relationship(deleteRule: .nullify, inverse: \Principle.intentions)
        var principle: Principle?

        var outcomeRaw: String?
        var closedAt: Date?
        var predecessorID: UUID?
        var promotionDismissed: Bool = false
        var questionText: String?
        var questionWindowStart: Date?
        var questionWindowEnd: Date?
        var createdAt: Date

        init(title: String, kindRaw: String, weekStart: Date, createdAt: Date = .now) {
            stableID = UUID()
            self.title = title
            self.kindRaw = kindRaw
            self.weekStart = weekStart
            self.createdAt = createdAt
        }
    }

    @Model
    final class AspirationCheckIn {
        #Unique<AspirationCheckIn>([\.stableID])
        var stableID: UUID?
        var weekStart: Date
        var ratingRaw: Int
        var note: String = ""
        var createdAt: Date
        var aspiration: Aspiration?

        init(ratingRaw: Int, weekStart: Date, createdAt: Date = .now) {
            stableID = UUID()
            self.ratingRaw = ratingRaw
            self.weekStart = weekStart
            self.createdAt = createdAt
        }
    }
}
#endif
