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
        reminderAt: Date?,
        repeatIntervalDays: Int?,
        points: Int
    ) async -> TaskItem? {
        let trimmedTitle = TaskItem.normalizedTitle(title)
        guard !trimmedTitle.isEmpty else { return nil }
        let interval = RepeatPolicy.normalizedInterval(repeatIntervalDays)
        let pointValue = ScorePolicy.normalizedPoints(points)

        let task: TaskItem
        if let existing {
            task = existing
            task.title = trimmedTitle
            task.notes = TaskItem.normalizedNotes(notes)
            task.dueDate = CalendarDay.startOfDay(dueDate)
            task.reminderAt = reminderAt
            task.repeatIntervalDays = interval
            task.points = pointValue
        } else {
            task = TaskItem(
                title: trimmedTitle,
                notes: notes,
                dueDate: dueDate,
                reminderAt: reminderAt,
                sortOrder: nextSortOrder(for: CalendarDay.startOfDay(dueDate)),
                repeatIntervalDays: interval,
                points: pointValue
            )
            context.insert(task)
        }

        persist()
        await sync(task)
        return task
    }

    func toggleCompleted(_ task: TaskItem) async {
        let wasCompleted = task.isCompleted
        task.isCompleted.toggle()
        persist()
        await sync(task)

        if RepeatPolicy.shouldSpawnNext(
            wasCompleted: wasCompleted,
            isCompleted: task.isCompleted,
            intervalDays: task.repeatIntervalDays
        ) {
            await spawnNextOccurrence(from: task)
        }
    }

    func delete(_ task: TaskItem) async {
        let taskID = task.id
        scheduler.cancel(taskID: taskID)
        context.delete(task)
        persist()
    }

    private func sync(_ task: TaskItem) async {
        await scheduler.syncReminder(
            taskID: task.id,
            title: task.title,
            notes: task.notes,
            reminderAt: task.reminderAt,
            isCompleted: task.isCompleted
        )
    }

    private func spawnNextOccurrence(from task: TaskItem) async {
        guard let next = RepeatPolicy.nextOccurrence(
            dueDate: task.dueDate,
            reminderAt: task.reminderAt,
            intervalDays: task.repeatIntervalDays
        ) else {
            return
        }

        if hasIncompleteOccurrence(
            title: task.title,
            dueDate: next.dueDate,
            intervalDays: next.intervalDays
        ) {
            return
        }

        let spawned = TaskItem(
            title: task.title,
            notes: task.notes,
            dueDate: next.dueDate,
            reminderAt: next.reminderAt,
            sortOrder: nextSortOrder(for: next.dueDate),
            repeatIntervalDays: next.intervalDays,
            points: task.points
        )
        context.insert(spawned)
        persist()
        await sync(spawned)
    }

    private func hasIncompleteOccurrence(title: String, dueDate: Date, intervalDays: Int) -> Bool {
        let range = CalendarDay.range(containing: dueDate)
        let start = range.start
        let end = range.end
        let descriptor = FetchDescriptor<TaskItem>(
            predicate: #Predicate { candidate in
                candidate.dueDate >= start && candidate.dueDate < end && candidate.isCompleted == false && candidate.title == title
            }
        )
        let matches = (try? context.fetch(descriptor)) ?? []
        return matches.contains { RepeatPolicy.normalizedInterval($0.repeatIntervalDays) == intervalDays }
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
