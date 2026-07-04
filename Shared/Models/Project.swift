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

    /// Back-array for the many-to-many with `Aspiration` (the `inverse:` lives on
    /// `Aspiration`). Plain, defaults empty — additive, no migration.
    var aspirations: [Aspiration] = []

    /// Back-array for the moments logged here as provenance. Plain (no macro):
    /// the `inverse:` lives on `Moment.project`, and both sides nullify —
    /// deleting a project drops the link and the moment survives. Defaults
    /// empty — additive, no migration.
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
