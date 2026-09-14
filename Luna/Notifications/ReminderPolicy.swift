import Foundation

enum ReminderPolicy {
    static let identifierPrefix = "luna.task."
    static let taskIDKey = "taskID"
    static let defaultBody = "Luna reminder"

    static func shouldSchedule(reminderAt: Date?, isCompleted: Bool, now: Date = .now) -> Bool {
        guard !isCompleted, let reminderAt else { return false }
        return reminderAt > now
    }

    static func notificationIdentifier(taskID: UUID) -> String {
        identifierPrefix + taskID.uuidString
    }

    static func userInfo(taskID: UUID) -> [AnyHashable: Any] {
        [taskIDKey: taskID.uuidString]
    }

    static func body(notes: String?) -> String {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? defaultBody : trimmed
    }
}
