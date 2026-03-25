import Foundation
import SwiftData

@Model
final class Project {
    var name: String
    var metric: Metric?
    var status: ProjectStatus
    var startedAt: Date
    var finishedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \Session.project)
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
