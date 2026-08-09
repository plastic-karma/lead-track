import Foundation
import UIKit
import UserNotifications

/// Routes notification taps into the app. Tapping any scheduled review
/// notification raises the flag the root tab shell answers by sliding to
/// the Week tab; tapping an intention's daily question raises the owning
/// aspiration's ID and the shell drills into its detail. Because the flags
/// live on a singleton set up before the first scene renders, a tap that
/// cold-launches the app still lands.
@MainActor
@Observable
final class NotificationResponder: NSObject {
    static let shared = NotificationResponder()

    var showWeeklyReview = false
    /// The aspiration a tapped daily question deep-links into; the shell
    /// consumes and clears it.
    var pendingAspirationID: UUID?

    /// Must run during app init so taps delivered at launch reach us.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Raises the flag matching the tapped notification; the root tab shell
    /// consumes it.
    private func route(_ request: UNNotificationRequest) {
        if NotificationService.isReviewNotification(id: request.identifier) {
            showWeeklyReview = true
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
