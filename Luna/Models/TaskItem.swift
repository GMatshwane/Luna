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
    var repeatIntervalDays: Int? = nil
    var repeatKindRaw: String? = nil
    var repeatWeekdaysMask: Int = 0
    var repeatMonthDay: Int? = nil
    var repeatMonth: Int? = nil
    var points: Int = 1
    var category: Category? = nil

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        dueDate: Date,
        reminderAt: Date? = nil,
        isCompleted: Bool = false,
        createdAt: Date = .now,
        sortOrder: Int = 0,
        repeatIntervalDays: Int? = nil,
        recurrence: RecurrenceRule? = nil,
        points: Int = ScorePolicy.defaultPoints,
        category: Category? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = Self.normalizedNotes(notes)
        self.dueDate = CalendarDay.startOfDay(dueDate)
        self.reminderAt = reminderAt
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.points = ScorePolicy.normalizedPoints(points)
        self.category = category
        apply(RepeatPolicy.normalized(recurrence) ?? RepeatPolicy.normalized(.everyNDays(repeatIntervalDays ?? 0)))
    }

    var recurrence: RecurrenceRule? {
        get { RepeatPolicy.rule(fromStored: storedRepeatFields) }
        set { apply(RepeatPolicy.normalized(newValue)) }
    }

    var storedRepeatFields: RepeatPolicy.StoredFields {
        RepeatPolicy.StoredFields(
            kindRaw: repeatKindRaw,
            intervalDays: repeatIntervalDays,
            weekdaysMask: repeatWeekdaysMask,
            monthDay: repeatMonthDay,
            month: repeatMonth
        )
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

    private func apply(_ rule: RecurrenceRule?) {
        let fields = RepeatPolicy.storedFields(from: rule)
        repeatKindRaw = fields.kindRaw
        repeatIntervalDays = fields.intervalDays
        repeatWeekdaysMask = fields.weekdaysMask
        repeatMonthDay = fields.monthDay
        repeatMonth = fields.month
    }
}
