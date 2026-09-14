import Foundation
import SwiftData

@MainActor
struct TaskService {
    var context: ModelContext
    var scheduler: NotificationScheduler

    func save(
        existing: TaskItem?,
        title: String,
        notes: String?,
        dueDate: Date,
        reminderAt: Date?
    ) async -> TaskItem? {
        let trimmedTitle = TaskItem.normalizedTitle(title)
        guard !trimmedTitle.isEmpty else { return nil }

        let task: TaskItem
        if let existing {
            task = existing
            task.title = trimmedTitle
            task.notes = TaskItem.normalizedNotes(notes)
            task.dueDate = CalendarDay.startOfDay(dueDate)
            task.reminderAt = reminderAt
        } else {
            task = TaskItem(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                reminderAt: reminderAt,
                sortOrder: nextSortOrder(for: CalendarDay.startOfDay(dueDate))
            )
            context.insert(task)
        }

        persist()
        await scheduler.syncReminder(
            taskID: task.id,
            title: task.title,
            notes: task.notes,
            reminderAt: task.reminderAt,
            isCompleted: task.isCompleted
        )
        return task
    }

    func toggleCompleted(_ task: TaskItem) async {
        task.isCompleted.toggle()
        persist()
        await scheduler.syncReminder(
            taskID: task.id,
            title: task.title,
            notes: task.notes,
            reminderAt: task.reminderAt,
            isCompleted: task.isCompleted
        )
    }

    func delete(_ task: TaskItem) async {
        let taskID = task.id
        scheduler.cancel(taskID: taskID)
        context.delete(task)
        persist()
    }

    private func persist() {
        do {
            try context.save()
        } catch {
            assertionFailure("Failed to save Luna store: \(error)")
        }
    }

    private func nextSortOrder(for dueDate: Date) -> Int {
        let range = CalendarDay.range(containing: dueDate)
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { task in
                task.dueDate >= start && task.dueDate < end
            },
            sortBy: [SortDescriptor(\.sortOrder, order: .reverse)]
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        return (existing.first?.sortOrder ?? -1) + 1
    }
}
