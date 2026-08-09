#if canImport(UserNotifications)
import Foundation
import UserNotifications

/// One calendar-safe notification per configured additional review. The next
/// boundary is replenished on every foreground pass and whenever the user
/// adds, edits, or removes a definition.
extension NotificationService {
    static let additionalReviewDeepLinkKey = "additionalReviewID"
    private static let additionalReviewPrefix = "additional-review-"

    static func isAdditionalReviewNotification(id: String) -> Bool {
        id.hasPrefix(additionalReviewPrefix)
    }

    static func additionalReviewID(from userInfo: [AnyHashable: Any]) -> UUID? {
        let raw = userInfo[additionalReviewDeepLinkKey] as? String
        return raw.flatMap(UUID.init(uuidString:))
    }

    /// Removes every prior additional-review request — including a review
    /// just deleted from storage — then arms the next boundary of each
    /// remaining definition.
    static func rescheduleAdditionalReviews() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests
                .map(\.identifier)
                .filter { isAdditionalReviewNotification(id: $0) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
            scheduleAllAdditionalReviews()
        }
    }

    static func scheduleAllAdditionalReviews() {
        for review in AdditionalReviewStore.reviews() {
            let date = AdditionalReviewSchedule.nextReviewDate(for: review)
            let content = additionalReviewContent(for: review)
            content.userInfo[additionalReviewDeepLinkKey] = review.id.uuidString
            schedule(
                id: "\(additionalReviewPrefix)\(review.id.uuidString)",
                content: content,
                trigger: calendarTrigger(for: date)
            )
        }
    }

    private static func additionalReviewContent(
        for review: AdditionalReview
    ) -> UNMutableNotificationContent {
        let copy = NotificationPrivacy.isDiscreet()
            ? (
                title: "Review Ready",
                body: "A review period has ended — open LeadStone to look back."
            )
            : (
                title: "\(review.name) Ready",
                body: "A new period has started — open your review to look back."
            )
        return makeContent(copy)
    }
}
#endif
