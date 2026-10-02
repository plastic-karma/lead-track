#if canImport(SwiftData)
import Foundation
import SwiftData

/// Persisted testimony and external blobs from 2e61bd0.
extension LeadTrackSchemaV1 {
    @Model
    final class Moment {
        #Unique<Moment>([\.stableID])
        var stableID: UUID?
        var text: String
        var occurredAt: Date
        var createdAt: Date
        var latitude: Double?
        var longitude: Double?
        var placeName: String = ""
        var aspiration: Aspiration?

        @Relationship(deleteRule: .nullify, inverse: \Metric.moments)
        var metric: Metric?
        @Relationship(deleteRule: .nullify, inverse: \Project.moments)
        var project: Project?
        @Relationship(deleteRule: .nullify, inverse: \Principle.moments)
        var principle: Principle?
        @Relationship(deleteRule: .cascade, inverse: \MomentPhoto.moment)
        var photos: [MomentPhoto] = []

        init(text: String, occurredAt: Date = .now, createdAt: Date = .now) {
            stableID = UUID()
            self.text = text
            self.occurredAt = occurredAt
            self.createdAt = createdAt
        }
    }

    @Model
    final class MomentPhoto {
        @Attribute(.externalStorage)
        var data: Data
        var sortIndex: Int
        var moment: Moment?

        init(data: Data, sortIndex: Int = 0) {
            self.data = data
            self.sortIndex = sortIndex
        }
    }
}
#endif
