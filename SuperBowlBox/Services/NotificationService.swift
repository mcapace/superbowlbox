import Foundation
import UIKit
import UserNotifications

/// Handles push notification permission and registration. Enable "Push Notifications" in Xcode
/// (Signing & Capabilities) and configure your backend to send APNs payloads to the device token.
enum NotificationService {
    static var isAuthorized: Bool { false } // Updated after first request

    /// Call early in app lifecycle (e.g. from App init or scene phase .active).
    static func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// Call from AppDelegate / SceneDelegate when device token is received.
    static func didRegisterForRemoteNotifications(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "apnsDeviceToken")
        // Send token to your backend so it can target this device for score updates, winner alerts, etc.
    }

    static func didFailToRegisterForRemoteNotifications(error: Error) {
        // Log or retry as needed
    }

    // MARK: - Local notifications (driven by app reviewing what’s happening)

    /// Schedules a local notification so the app can push information based on score/pool context.
    /// Use a stable identifier so you can replace or avoid duplicates (e.g. "poolLead-\(poolId)").
    static func scheduleLocal(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
