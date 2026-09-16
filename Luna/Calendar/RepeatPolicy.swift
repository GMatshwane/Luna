import Foundation

enum RecurrenceRule: Equatable, Hashable, Codable {
    case everyNDays(Int)
    case weekdays(Set<Int>)
    case weekly
    case monthly(dayOfMonth: Int)
    case yearly(month: Int, day: Int)
}

enum RepeatPolicy {
    static let minimumIntervalDays = 1
    static let maximumIntervalDays = 365
    static let mondayThroughFriday: Set<Int> = [2, 3, 4, 5, 6]
    static let weekendDays: Set<Int> = [1, 7]

    struct NextOccurrence: Equatable {
        var dueDate: Date
        var reminderAt: Date?
        var rule: RecurrenceRule

        var intervalDays: Int {
            if case .everyNDays(let days) = rule {
                return days
            }
            return 0
        }
    }

    struct StoredFields: Equatable {
        var kindRaw: String? = nil
        var intervalDays: Int? = nil
        var weekdaysMask: Int = 0
        var monthDay: Int? = nil
        var month: Int? = nil
    }

    static func normalizedInterval(_ days: Int?) -> Int? {
        guard let days, days >= minimumIntervalDays else { return nil }
        return min(days, maximumIntervalDays)
    }

    static func normalized(_ rule: RecurrenceRule?) -> RecurrenceRule? {
        guard let rule else { return nil }
        switch rule {
        case .everyNDays(let days):
            guard let interval = normalizedInterval(days) else { return nil }
            return .everyNDays(interval)
        case .weekdays(let days):
            let valid = Set(days.filter { (1...7).contains($0) })
            return valid.isEmpty ? nil : .weekdays(valid)
        case .weekly:
            return .weekly
        case .monthly(let day):
            return .monthly(dayOfMonth: min(max(day, 1), 31))
        case .yearly(let month, let day):
            return .yearly(month: min(max(month, 1), 12), day: min(max(day, 1), 31))
        }
    }

    static func shouldSpawnNext(wasCompleted: Bool, isCompleted: Bool, intervalDays: Int?) -> Bool {
        shouldSpawnNext(wasCompleted: wasCompleted, isCompleted: isCompleted, rule: rule(fromInterval: intervalDays))
    }

    static func shouldSpawnNext(wasCompleted: Bool, isCompleted: Bool, rule: RecurrenceRule?) -> Bool {
        isCompleted && !wasCompleted && normalized(rule) != nil
    }

    static func nextOccurrence(
        dueDate: Date,
        reminderAt: Date?,
        intervalDays: Int?,
        calendar: Calendar = .current
    ) -> NextOccurrence? {
        nextOccurrence(dueDate: dueDate, reminderAt: reminderAt, rule: rule(fromInterval: intervalDays), calendar: calendar)
    }

    static func nextOccurrence(
        dueDate: Date,
        reminderAt: Date?,
        rule: RecurrenceRule?,
        calendar: Calendar = .current
    ) -> NextOccurrence? {
        guard let rule = normalized(rule) else { return nil }
        let start = CalendarDay.startOfDay(dueDate, calendar: calendar)
        guard let nextDue = nextDueDate(from: start, rule: rule, calendar: calendar) else { return nil }
        let nextReminder = shiftedReminder(reminderAt, from: start, to: nextDue, calendar: calendar)
        return NextOccurrence(dueDate: nextDue, reminderAt: nextReminder, rule: rule)
    }

    static func summaryLabel(intervalDays: Int) -> String {
        summaryLabel(.everyNDays(intervalDays))
    }

    static func summaryLabel(_ rule: RecurrenceRule) -> String {
        guard let rule = normalized(rule) else { return "Does not repeat" }
        switch rule {
        case .everyNDays(let days):
            return days == 1 ? "Every day" : "Every \(days) days"
        case .weekdays(let days):
            if days == mondayThroughFriday { return "Every weekday" }
            if days == weekendDays { return "Every weekend" }
            return weekdayNames(days)
        case .weekly:
            return "Every week"
        case .monthly:
            return "Every month"
        case .yearly:
            return "Every year"
        }
    }

    static func rulesMatch(_ lhs: RecurrenceRule?, _ rhs: RecurrenceRule?) -> Bool {
        normalized(lhs) == normalized(rhs)
    }

    static func storedFields(from rule: RecurrenceRule?) -> StoredFields {
        guard let rule = normalized(rule) else { return StoredFields() }
        switch rule {
        case .everyNDays(let days):
            return StoredFields(kindRaw: "everyNDays", intervalDays: days)
        case .weekdays(let days):
            return StoredFields(kindRaw: "weekdays", weekdaysMask: mask(from: days))
        case .weekly:
            return StoredFields(kindRaw: "weekly")
        case .monthly(let day):
            return StoredFields(kindRaw: "monthly", monthDay: day)
        case .yearly(let month, let day):
            return StoredFields(kindRaw: "yearly", monthDay: day, month: month)
        }
    }

    static func rule(fromStored fields: StoredFields) -> RecurrenceRule? {
        switch fields.kindRaw {
        case nil:
            return rule(fromInterval: fields.intervalDays)
        case "everyNDays":
            return normalized(.everyNDays(fields.intervalDays ?? 0))
        case "weekdays":
            return normalized(.weekdays(weekdays(from: fields.weekdaysMask)))
        case "weekly":
            return .weekly
        case "monthly":
            return normalized(.monthly(dayOfMonth: fields.monthDay ?? 1))
        case "yearly":
            return normalized(.yearly(month: fields.month ?? 1, day: fields.monthDay ?? 1))
        default:
            return rule(fromInterval: fields.intervalDays)
        }
    }

    static func mask(from weekdays: Set<Int>) -> Int {
        weekdays.reduce(0) { $0 | (1 << $1) }
    }

    static func weekdays(from mask: Int) -> Set<Int> {
        Set((1...7).filter { mask & (1 << $0) != 0 })
    }

    private static func rule(fromInterval days: Int?) -> RecurrenceRule? {
        guard let interval = normalizedInterval(days) else { return nil }
        return .everyNDays(interval)
    }

    private static func nextDueDate(from start: Date, rule: RecurrenceRule, calendar: Calendar) -> Date? {
        switch rule {
        case .everyNDays(let days):
            let advanced = calendar.date(byAdding: .day, value: days, to: start) ?? start
            return CalendarDay.startOfDay(advanced, calendar: calendar)
        case .weekdays(let days):
            return nextSelectedWeekday(after: start, weekdays: days, calendar: calendar)
        case .weekly:
            let advanced = calendar.date(byAdding: .day, value: 7, to: start) ?? start
            return CalendarDay.startOfDay(advanced, calendar: calendar)
        case .monthly(let dayOfMonth):
            return dateByAdding(months: 1, dayOfMonth: dayOfMonth, from: start, calendar: calendar)
        case .yearly(let month, let day):
            return dateByAdding(years: 1, month: month, day: day, from: start, calendar: calendar)
        }
    }

    private static func nextSelectedWeekday(after start: Date, weekdays: Set<Int>, calendar: Calendar) -> Date? {
        for offset in 1...7 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: start) else { continue }
            let weekday = calendar.component(.weekday, from: candidate)
            if weekdays.contains(weekday) {
                return CalendarDay.startOfDay(candidate, calendar: calendar)
            }
        }
        return nil
    }

    private static func dateByAdding(months: Int, dayOfMonth: Int, from start: Date, calendar: Calendar) -> Date? {
        let parts = calendar.dateComponents([.year, .month], from: start)
        guard
            let monthStart = calendar.date(from: DateComponents(year: parts.year, month: parts.month, day: 1)),
            let nextMonthStart = calendar.date(byAdding: .month, value: months, to: monthStart),
            let dayRange = calendar.range(of: .day, in: .month, for: nextMonthStart)
        else {
            return nil
        }
        let nextParts = calendar.dateComponents([.year, .month], from: nextMonthStart)
        let day = min(max(dayOfMonth, 1), dayRange.count)
        let next = calendar.date(from: DateComponents(year: nextParts.year, month: nextParts.month, day: day))
        return next.map { CalendarDay.startOfDay($0, calendar: calendar) }
    }

    private static func dateByAdding(years: Int, month: Int, day: Int, from start: Date, calendar: Calendar) -> Date? {
        let year = (calendar.component(.year, from: start)) + years
        guard
            let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
            let dayRange = calendar.range(of: .day, in: .month, for: monthStart)
        else {
            return nil
        }
        let clampedDay = min(max(day, 1), dayRange.count)
        let next = calendar.date(from: DateComponents(year: year, month: month, day: clampedDay))
        return next.map { CalendarDay.startOfDay($0, calendar: calendar) }
    }

    private static func shiftedReminder(
        _ reminderAt: Date?,
        from start: Date,
        to nextDue: Date,
        calendar: Calendar
    ) -> Date? {
        guard let reminderAt else { return nil }
        let days = calendar.dateComponents([.day], from: start, to: nextDue).day ?? 0
        return calendar.date(byAdding: .day, value: days, to: reminderAt)
    }

    private static func weekdayNames(_ days: Set<Int>) -> String {
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return (1...7).compactMap { day in
            days.contains(day) ? symbols[day] : nil
        }.joined(separator: ", ")
    }
}
