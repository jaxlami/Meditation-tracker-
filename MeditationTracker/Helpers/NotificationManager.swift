import Foundation
import UserNotifications

enum NotificationManager {
    private static let reminderID = "daily-meditation-reminder"
    private static let timerID = "meditation-timer-finished"

    /// Asks for permission if needed. Returns true when notifications are allowed.
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        default:
            return false
        }
    }

    static func scheduleDailyReminder(secondsAfterMidnight: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [reminderID])

        let content = UNMutableNotificationContent()
        content.title = "A moment to sit"
        content.body = "A few quiet minutes, whenever you are ready."
        content.sound = .default

        var components = DateComponents()
        components.hour = secondsAfterMidnight / 3600
        components.minute = (secondsAfterMidnight % 3600) / 60
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: reminderID, content: content, trigger: trigger))
    }

    static func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminderID])
    }

    /// Rings even if the app is in the background or the phone is locked.
    static func scheduleTimerEnd(after seconds: TimeInterval) {
        guard seconds >= 1 else { return }
        let content = UNMutableNotificationContent()
        content.title = "Session complete"
        content.body = "Take a breath. Today's reflection is waiting when you open the app."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: timerID, content: content, trigger: trigger))
    }

    static func cancelTimerEnd() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [timerID])
        center.removeDeliveredNotifications(withIdentifiers: [timerID])
    }
}
