import XCTest
@testable import Luna

final class WeekdayAbbreviationTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    func testEnglishLocaleUsesThreeLetterWeekdays() {
        let locale = Locale(identifier: "en_US_POSIX")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 14), locale: locale), "Mon")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 15), locale: locale), "Tue")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 16), locale: locale), "Wed")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 17), locale: locale), "Thu")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 18), locale: locale), "Fri")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 19), locale: locale), "Sat")
        XCTAssertEqual(WeekdayAbbreviation.compact(date(year: 2026, month: 9, day: 20), locale: locale), "Sun")
    }

    func testCompactLabelIsNotASingleNarrowLetter() {
        let locale = Locale(identifier: "en_US_POSIX")
        let monday = date(year: 2026, month: 9, day: 14)
        let compact = WeekdayAbbreviation.compact(monday, locale: locale)
        XCTAssertEqual(compact.count, 3)
        XCTAssertNotEqual(compact, monday.formatted(.dateTime.weekday(.narrow).locale(locale)))
    }

    func testFrenchLocaleStaysLocaleAware() {
        let locale = Locale(identifier: "fr_FR")
        let monday = date(year: 2026, month: 9, day: 14)
        let compact = WeekdayAbbreviation.compact(monday, locale: locale)
        XCTAssertFalse(compact.isEmpty)
        XCTAssertGreaterThan(compact.count, 1)
        XCTAssertNotEqual(compact.lowercased(), "l")
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)!
    }
}
