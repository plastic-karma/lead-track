import Combine
import Foundation
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
