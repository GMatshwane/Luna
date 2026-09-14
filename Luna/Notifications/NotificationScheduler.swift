import Foundation
import Observation
import UserNotifications

@Observable
@MainActor
final class NotificationScheduler {
    private let center: UNUserNotificationCenter
    var authorizationStatus: UNAuthorizationStatus = .notDetermined

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    var isDenied: Bool {
        authorizationStatus == .denied
    }

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> UNAuthorizationStatus {
        await refreshStatus()
        if authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshStatus()
        }
        return authorizationStatus
    }

    func cancel(taskID: UUID) {
        let identifier = ReminderPolicy.notificationIdentifier(taskID: taskID)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func syncReminder(
        taskID: UUID,
        title: String,
        notes: String?,
        reminderAt: Date?,
        isCompleted: Bool,
        now: Date = .now
    ) async {
        cancel(taskID: taskID)

        guard ReminderPolicy.shouldSchedule(reminderAt: reminderAt, isCompleted: isCompleted, now: now),
              let reminderAt else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = ReminderPolicy.body(notes: notes)
        content.sound = .default
        content.userInfo = ReminderPolicy.userInfo(taskID: taskID)

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderAt
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: ReminderPolicy.notificationIdentifier(taskID: taskID),
            content: content,
            trigger: trigger
        )

        try? await center.add(request)
    }
}

final class NotificationPresentationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationPresentationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
