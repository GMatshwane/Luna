import XCTest
@testable import Luna

final class CalendarDayTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testStartOfDayStripsTime() {
        let date = date(year: 2026, month: 9, day: 14, hour: 18, minute: 45)
        let start = CalendarDay.startOfDay(date, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 9)
        XCTAssertEqual(parts.day, 14)
        XCTAssertEqual(parts.hour, 0)
        XCTAssertEqual(parts.minute, 0)
        XCTAssertEqual(parts.second, 0)
    }

    func testRangeEndIsExclusiveNextStart() {
        let date = date(year: 2026, month: 9, day: 14, hour: 9, minute: 0)
        let range = CalendarDay.range(containing: date, calendar: calendar)
        XCTAssertEqual(range.start, CalendarDay.startOfDay(date, calendar: calendar))
        XCTAssertEqual(range.end, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 15), calendar: calendar))
        XCTAssertFalse(range.end <= range.start)
    }

    func testCombiningKeepsDayAndClockTime() {
        let day = date(year: 2026, month: 9, day: 16)
        let time = date(year: 1999, month: 1, day: 1, hour: 8, minute: 30)
        let combined = CalendarDay.combining(day: day, time: time, calendar: calendar)
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: combined)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 9)
        XCTAssertEqual(parts.day, 16)
        XCTAssertEqual(parts.hour, 8)
        XCTAssertEqual(parts.minute, 30)
    }

    func testSameDayIgnoresTime() {
        let morning = date(year: 2026, month: 9, day: 14, hour: 1)
        let evening = date(year: 2026, month: 9, day: 14, hour: 23)
        XCTAssertTrue(CalendarDay.isSameDay(morning, evening, calendar: calendar))
        XCTAssertFalse(CalendarDay.isSameDay(morning, date(year: 2026, month: 9, day: 15), calendar: calendar))
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
