import Foundation

/// The canonical display order for attached items — metrics by creation,
/// projects by start — shared by the attach pickers, the attached list, and
/// the detail summary so the surfaces can never disagree about ordering.
extension [Metric] {
    var inDisplayOrder: [Metric] {
        sorted { $0.createdAt < $1.createdAt }
    }
}

extension [Project] {
    var inDisplayOrder: [Project] {
        sorted { $0.startedAt < $1.startedAt }
    }
}
