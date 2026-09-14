import XCTest
@testable import Luna

final class RepeatPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testNilAndZeroIntervalsDoNotRepeat() {
        XCTAssertNil(RepeatPolicy.normalizedInterval(nil))
        XCTAssertNil(RepeatPolicy.normalizedInterval(0))
        XCTAssertNil(RepeatPolicy.normalizedInterval(-3))
    }

    func testIntervalIsClampedToAtLeastOneDay() {
        XCTAssertEqual(RepeatPolicy.normalizedInterval(1), 1)
        XCTAssertEqual(RepeatPolicy.normalizedInterval(14), 14)
        XCTAssertEqual(RepeatPolicy.normalizedInterval(400), RepeatPolicy.maximumIntervalDays)
    }

    func testSpawnOnlyOnTransitionToCompleted() {
        XCTAssertTrue(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: true, isCompleted: true, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: true, isCompleted: false, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, intervalDays: nil))
    }

    func testNextOccurrenceAdvancesDueDateByNDaysAtStartOfDay() {
        let due = date(year: 2026, month: 9, day: 14, hour: 18, minute: 45)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: due,
            reminderAt: nil,
            intervalDays: 3,
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 17), calendar: calendar))
        XCTAssertNil(next?.reminderAt)
        XCTAssertEqual(next?.intervalDays, 3)
    }

    func testNextOccurrenceShiftsReminderByTheSameCalendarOffset() {
        let due = date(year: 2026, month: 9, day: 14)
        let reminder = date(year: 2026, month: 9, day: 14, hour: 8, minute: 30)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: due,
            reminderAt: reminder,
            intervalDays: 7,
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 21), calendar: calendar))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next!.reminderAt!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 9)
        XCTAssertEqual(parts.day, 21)
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 30)
    }

    func testNonRepeatingProducesNoNextOccurrence() {
        XCTAssertNil(
            RepeatPolicy.nextOccurrence(
                dueDate: date(year: 2026, month: 9, day: 14),
                reminderAt: date(year: 2026, month: 9, day: 14, hour: 9),
                intervalDays: nil,
                calendar: calendar
            )
        )
    }

    func testSummaryLabel() {
        XCTAssertEqual(RepeatPolicy.summaryLabel(intervalDays: 1), "Every day")
        XCTAssertEqual(RepeatPolicy.summaryLabel(intervalDays: 3), "Every 3 days")
    }

    private func date(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
}
