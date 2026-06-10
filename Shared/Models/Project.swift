import Foundation
#if canImport(SwiftData)
import SwiftData
#endif

#if canImport(SwiftData)
@Model
#endif
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
