import Foundation

enum RepeatPolicy {
    static let minimumIntervalDays = 1
    static let maximumIntervalDays = 365

    struct NextOccurrence: Equatable {
        var dueDate: Date
        var reminderAt: Date?
        var intervalDays: Int
    }

    static func normalizedInterval(_ days: Int?) -> Int? {
        guard let days, days >= minimumIntervalDays else { return nil }
        return min(days, maximumIntervalDays)
    }

    static func shouldSpawnNext(wasCompleted: Bool, isCompleted: Bool, intervalDays: Int?) -> Bool {
        isCompleted && !wasCompleted && normalizedInterval(intervalDays) != nil
    }

    static func nextOccurrence(
        dueDate: Date,
        reminderAt: Date?,
        intervalDays: Int?,
        calendar: Calendar = .current
    ) -> NextOccurrence? {
        guard let interval = normalizedInterval(intervalDays) else { return nil }
        let start = CalendarDay.startOfDay(dueDate, calendar: calendar)
        let advanced = calendar.date(byAdding: .day, value: interval, to: start) ?? start
        let nextDue = CalendarDay.startOfDay(advanced, calendar: calendar)
        let nextReminder = reminderAt.flatMap { calendar.date(byAdding: .day, value: interval, to: $0) }
        return NextOccurrence(dueDate: nextDue, reminderAt: nextReminder, intervalDays: interval)
    }

    static func summaryLabel(intervalDays: Int) -> String {
        intervalDays == 1 ? "Every day" : "Every \(intervalDays) days"
    }
}
