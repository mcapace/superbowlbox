import Foundation
import UIKit
import UserNotifications

/// Handles notification permission, local notifications (game alerts, pool removed/updated), and remote push registration.
/// Push Notifications capability is in the entitlements (aps-environment); no extra Xcode setup needed for local notifications.
enum NotificationService {
    private static let authorizedKey = "notificationService_authorized"

    /// Cached authorization status; updated after requestPermissionAndRegister completes.
    static var isAuthorized: Bool {
        UserDefaults.standard.bool(forKey: authorizedKey)
    }

    /// Call early in app lifecycle (ContentView.onAppear). Requests permission and registers for remote notifications if granted.
    static func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            let alreadyAuthorized = settings.authorizationStatus == .authorized
            if alreadyAuthorized {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(true, forKey: authorizedKey)
                    UIApplication.shared.registerForRemoteNotifications()
                }
                return
            }
            if settings.authorizationStatus == .denied { return }

            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
                DispatchQueue.main.async {
                    UserDefaults.standard.set(granted, forKey: authorizedKey)
                    if granted {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }

    /// Call from AppDelegate when device token is received (required for remote push; optional for local-only).
    static func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
    }

    static func didFailToRegisterForRemoteNotifications(error: Error) {
        // On simulator, remote registration fails; local notifications still work.
    }

    // MARK: - Local notifications (game context, pool removed/updated)

    /// Schedules a local notification. Used for: you're leading, period winner, one score away, pool removed/updated by host.
    /// System will only show if user has granted permission.
    static func scheduleLocal(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

// MARK: - Foreground presentation (show banner/sound when app is open)
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
