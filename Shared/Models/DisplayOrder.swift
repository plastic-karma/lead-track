import Foundation

/// The canonical display orders shared across surfaces so they can never
/// disagree about ordering: attached metrics by creation and projects by
/// start (the attach pickers, the attached list, the detail summary), and
/// aspirations by their manual ranks (the three tabs' card stacks).
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

/// The canonical aspiration order every card stack shares — Today's clusters,
/// the Week tab's metric groups, the Aspirations list — so a drag on any tab
/// rearranges all three the same way: manually ranked aspirations first in
/// rank order, then the never-ranked ones in creation order, which keeps an
/// app that has never been reordered exactly as it always looked.
extension [Aspiration] {
    var inDisplayOrder: [Aspiration] {
        sorted { lhs, rhs in
            switch (lhs.displayOrder, rhs.displayOrder) {
            case let (lhsRank?, rhsRank?):
                lhsRank == rhsRank ? lhs.createdAt < rhs.createdAt : lhsRank < rhsRank
            case (.some, nil):
                true
            case (nil, .some):
                false
            case (nil, nil):
                lhs.createdAt < rhs.createdAt
            }
        }
    }

    /// Whether the user has ever dragged a card into place — the moment
    /// manual order permanently replaces the derived orders.
    var hasManualOrder: Bool {
        contains { $0.displayOrder != nil }
    }
}
