import Foundation
import UIKit
import UserNotifications

/// Routes notification taps into the app. Metric reminders and countdowns
/// open that metric's detail; the fixed weekly review still slides to the
/// Week tab; an additional review opens that definition's completed-period
/// report; and an intention question opens its aspiration. Because the flags
/// live on a singleton installed before the first scene renders, a tap that
/// cold-launches the app still lands.
@MainActor
@Observable
final class NotificationResponder: NSObject {
    static let shared = NotificationResponder()

    var showWeeklyReview = false
    /// The aspiration a tapped daily question deep-links into; the shell
    /// consumes and clears it.
    var pendingAspirationID: UUID?
    /// The additional review selected by a notification; the shell consumes
    /// and clears it before presenting the report.
    var pendingAdditionalReviewID: UUID?
    /// The metric selected by a reminder, streak alert, or countdown.
    var pendingMetricID: UUID?

    /// Must run during app init so taps delivered at launch reach us.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Raises the flag matching the tapped notification; the root tab shell
    /// consumes it.
    private func route(_ request: UNNotificationRequest) {
        if let metricID = MetricNotificationRoute.metricID(from: request.content.userInfo) {
            pendingMetricID = metricID
        } else if request.identifier == NotificationService.weeklyReviewNotificationID {
            showWeeklyReview = true
        } else if NotificationService.isAdditionalReviewNotification(id: request.identifier) {
            pendingAdditionalReviewID = NotificationService.additionalReviewID(
                from: request.content.userInfo
            )
        } else if NotificationService.isIntentionQuestion(id: request.identifier) {
            routeToAspiration(from: request.content.userInfo)
        }
    }

    private func routeToAspiration(from userInfo: [AnyHashable: Any]) {
        let raw = userInfo[NotificationService.aspirationDeepLinkKey] as? String
        guard let id = raw.flatMap(UUID.init(uuidString:)) else { return }
        pendingAspirationID = id
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationResponder: UNUserNotificationCenterDelegate {
    /// Surfaces a countdown's "time's up" alert even while the app is open,
    /// pinging and/or vibrating per the user's toggles; other notifications
    /// stay silent in the foreground as before.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let id = notification.request.identifier
        guard NotificationService.isCountdownNotification(id: id) else {
            completionHandler([])
            return
        }
        var options: UNNotificationPresentationOptions = [.banner]
        if CompletionAlertSettings.soundEnabled {
            options.insert(.sound)
        }
        completionHandler(options)
        if CompletionAlertSettings.hapticEnabled {
            Task { @MainActor in
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let request = response.notification.request
        Task { @MainActor in
            route(request)
        }
        completionHandler()
    }
}
