import Combine
import Foundation
import UIKit
import UserNotifications

/// Routes notification taps into the app. Tapping the weekly review
/// notification raises the flag the dashboard binds its review sheet to;
/// because the flag lives on a singleton set up before the first scene
/// renders, a tap that cold-launches the app still lands.
final class NotificationResponder: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationResponder()

    @Published var showWeeklyReview = false

    /// Must run during app init so taps delivered at launch reach us.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    /// Surfaces a countdown's "time's up" alert even while the app is open,
    /// pinging and/or vibrating per the user's toggles; other notifications
    /// stay silent in the foreground as before.
    func userNotificationCenter(
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

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let id = response.notification.request.identifier
        if id == NotificationService.weeklyReviewNotificationID {
            DispatchQueue.main.async { [weak self] in
                self?.showWeeklyReview = true
            }
        }
        completionHandler()
    }
}
