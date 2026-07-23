import Foundation

/// The photo interval shown by the Week tab's recent-photo doorway. Its bounds
/// come directly from `WeeklyReview`, so photo selection and the review itself
/// use one period definition even while browsing an earlier week.
struct RecentPhotoWindow: Equatable {
    /// Inclusive lower bound, matching `WeeklyReview.PeriodBounds`.
    let start: Date
    /// Exclusive upper bound, matching sessions and moments in the review.
    let end: Date

    /// Photos without a creation date cannot be proven recent and stay out.
    func contains(_ creationDate: Date?) -> Bool {
        guard let creationDate else { return false }
        return creationDate >= start && creationDate < end
    }
}
