import Foundation
import SwiftData

@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String?
    var dueDate: Date
    var reminderAt: Date?
    var isCompleted: Bool
    var createdAt: Date
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date,
        reminderAt: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.notes = Self.normalizedNotes(notes)
        self.dueDate = CalendarDay.startOfDay(dueDate)
        self.reminderAt = reminderAt
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
    }

    var sortKey: TaskSortKey {
        TaskSortKey(reminderAt: reminderAt, sortOrder: sortOrder, createdAt: createdAt)
    }

    static func normalizedNotes(_ notes: String?) -> String? {
        let trimmed = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    static func normalizedTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
