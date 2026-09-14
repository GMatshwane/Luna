import Foundation

enum CalendarDay {
    static func startOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.startOfDay(for: date)
    }

    static func endOfDay(_ date: Date, calendar: Calendar = .current) -> Date {
        let start = startOfDay(date, calendar: calendar)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? start
    }

    static func range(containing date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        (startOfDay(date, calendar: calendar), endOfDay(date, calendar: calendar))
    }

    static func isSameDay(_ lhs: Date, _ rhs: Date, calendar: Calendar = .current) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    static func combining(day: Date, time: Date, calendar: Calendar = .current) -> Date {
        let dayParts = calendar.dateComponents([.year, .month, .day], from: startOfDay(day, calendar: calendar))
        let timeParts = calendar.dateComponents([.hour, .minute], from: time)
        var combined = DateComponents()
        combined.year = dayParts.year
        combined.month = dayParts.month
        combined.day = dayParts.day
        combined.hour = timeParts.hour
        combined.minute = timeParts.minute
        return calendar.date(from: combined) ?? startOfDay(day, calendar: calendar)
    }

    static func nearbyDays(around date: Date, before: Int = 14, after: Int = 28, calendar: Calendar = .current) -> [Date] {
        let origin = startOfDay(date, calendar: calendar)
        return (-before...after).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: origin)
        }
    }
}
