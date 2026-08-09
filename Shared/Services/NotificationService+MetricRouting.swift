import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Stable metadata carried by every metric-specific notification. Keeping the
/// identifier out of banner copy lets notification taps resolve the metric
/// even when privacy settings hide its name.
enum MetricNotificationRoute {
    private static let metricIDKey = "metricStableID"

    static func userInfo(for metricID: UUID) -> [AnyHashable: Any] {
        [metricIDKey: metricID.uuidString]
    }

    static func metricID(from userInfo: [AnyHashable: Any]) -> UUID? {
        let rawID = userInfo[metricIDKey] as? String
        return rawID.flatMap(UUID.init(uuidString:))
    }
}

#if canImport(UserNotifications)
extension NotificationService {
    static func metricContent(
        _ copy: (title: String, body: String),
        metricID: UUID
    ) -> UNMutableNotificationContent {
        let content = makeContent(copy)
        content.userInfo = MetricNotificationRoute.userInfo(for: metricID)
        return content
    }
}
#endif
