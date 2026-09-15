import XCTest
@testable import Luna

final class RepeatPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }

    private var newYork: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.firstWeekday = 1
        return calendar
    }

    func testNilAndZeroIntervalsDoNotRepeat() {
        XCTAssertNil(RepeatPolicy.normalizedInterval(nil))
        XCTAssertNil(RepeatPolicy.normalizedInterval(0))
        XCTAssertNil(RepeatPolicy.normalizedInterval(-3))
        XCTAssertNil(RepeatPolicy.normalized(nil))
        XCTAssertNil(RepeatPolicy.normalized(.everyNDays(0)))
        XCTAssertNil(RepeatPolicy.normalized(.weekdays([])))
    }

    func testIntervalIsClampedToAtLeastOneDay() {
        XCTAssertEqual(RepeatPolicy.normalizedInterval(1), 1)
        XCTAssertEqual(RepeatPolicy.normalizedInterval(14), 14)
        XCTAssertEqual(RepeatPolicy.normalizedInterval(400), RepeatPolicy.maximumIntervalDays)
        XCTAssertEqual(RepeatPolicy.normalized(.everyNDays(400)), .everyNDays(RepeatPolicy.maximumIntervalDays))
    }

    func testWeekdaysKeepOnlyValidCalendarWeekdays() {
        XCTAssertEqual(RepeatPolicy.normalized(.weekdays([0, 2, 2, 9, 6])), .weekdays([2, 6]))
        XCTAssertNil(RepeatPolicy.normalized(.weekdays([0, 8])))
        XCTAssertEqual(
            RepeatPolicy.normalized(.monthly(dayOfMonth: 0)),
            .monthly(dayOfMonth: 1)
        )
        XCTAssertEqual(
            RepeatPolicy.normalized(.monthly(dayOfMonth: 40)),
            .monthly(dayOfMonth: 31)
        )
        XCTAssertEqual(
            RepeatPolicy.normalized(.yearly(month: 0, day: 40)),
            .yearly(month: 1, day: 31)
        )
    }

    func testSpawnOnlyOnTransitionToCompleted() {
        XCTAssertTrue(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: true, isCompleted: true, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: true, isCompleted: false, intervalDays: 3))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, intervalDays: nil))
        XCTAssertTrue(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, rule: .weekly))
        XCTAssertFalse(RepeatPolicy.shouldSpawnNext(wasCompleted: false, isCompleted: true, rule: nil))
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
        XCTAssertEqual(next?.rule, .everyNDays(3))
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

    func testWeekdaysSkipToTheNextSelectedWeekday() {
        // Monday 14 Sep 2026
        let monday = date(year: 2026, month: 9, day: 14)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: monday,
            reminderAt: nil,
            rule: .weekdays(RepeatPolicy.mondayThroughFriday),
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 15), calendar: calendar))
        XCTAssertEqual(next?.rule, .weekdays(RepeatPolicy.mondayThroughFriday))
    }

    func testWeekdaysFromFridayLandOnMonday() {
        let friday = date(year: 2026, month: 9, day: 18)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: friday,
            reminderAt: date(year: 2026, month: 9, day: 18, hour: 7, minute: 15),
            rule: .weekdays(RepeatPolicy.mondayThroughFriday),
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 21), calendar: calendar))
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: next!.reminderAt!)
        XCTAssertEqual(parts.day, 21)
        XCTAssertEqual(parts.hour, 7)
        XCTAssertEqual(parts.minute, 15)
    }

    func testWeekendRuleAdvancesSaturdayToSundayThenMondaySkipped() {
        let saturday = date(year: 2026, month: 9, day: 19)
        let sunday = RepeatPolicy.nextOccurrence(
            dueDate: saturday,
            reminderAt: nil,
            rule: .weekdays(RepeatPolicy.weekendDays),
            calendar: calendar
        )
        XCTAssertEqual(sunday?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 20), calendar: calendar))

        let nextWeekend = RepeatPolicy.nextOccurrence(
            dueDate: sunday!.dueDate,
            reminderAt: nil,
            rule: .weekdays(RepeatPolicy.weekendDays),
            calendar: calendar
        )
        XCTAssertEqual(nextWeekend?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 26), calendar: calendar))
    }

    func testCustomWeekdaysUseTheSoonestMatchingDay() {
        let wednesday = date(year: 2026, month: 9, day: 16)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: wednesday,
            reminderAt: nil,
            rule: .weekdays([2, 5]), // Monday and Thursday
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 17), calendar: calendar))
    }

    func testWeeklyKeepsTheSameWeekday() {
        let thursday = date(year: 2026, month: 9, day: 17)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: thursday,
            reminderAt: date(year: 2026, month: 9, day: 17, hour: 9),
            rule: .weekly,
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 9, day: 24), calendar: calendar))
        XCTAssertEqual(calendar.component(.weekday, from: next!.dueDate), 5)
        XCTAssertEqual(next?.rule, .weekly)
        let parts = calendar.dateComponents([.day, .hour], from: next!.reminderAt!)
        XCTAssertEqual(parts.day, 24)
        XCTAssertEqual(parts.hour, 9)
    }

    func testMonthlyClampsToLastDayOfShorterMonthAndPreservesOriginalDay() {
        let january31 = date(year: 2026, month: 1, day: 31)
        let february = RepeatPolicy.nextOccurrence(
            dueDate: january31,
            reminderAt: date(year: 2026, month: 1, day: 31, hour: 8, minute: 0),
            rule: .monthly(dayOfMonth: 31),
            calendar: calendar
        )
        XCTAssertEqual(february?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 2, day: 28), calendar: calendar))
        XCTAssertEqual(february?.rule, .monthly(dayOfMonth: 31))

        let march = RepeatPolicy.nextOccurrence(
            dueDate: february!.dueDate,
            reminderAt: february!.reminderAt,
            rule: february!.rule,
            calendar: calendar
        )
        XCTAssertEqual(march?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 3, day: 31), calendar: calendar))
        let reminderParts = calendar.dateComponents([.month, .day, .hour], from: march!.reminderAt!)
        XCTAssertEqual(reminderParts.month, 3)
        XCTAssertEqual(reminderParts.day, 31)
        XCTAssertEqual(reminderParts.hour, 8)
    }

    func testMonthlyFromMidMonthKeepsTheSameDay() {
        let next = RepeatPolicy.nextOccurrence(
            dueDate: date(year: 2026, month: 4, day: 12),
            reminderAt: nil,
            rule: .monthly(dayOfMonth: 12),
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 5, day: 12), calendar: calendar))
    }

    func testYearlyClampsLeapDayToFebruary28() {
        let leap = date(year: 2024, month: 2, day: 29)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: leap,
            reminderAt: date(year: 2024, month: 2, day: 29, hour: 10, minute: 5),
            rule: .yearly(month: 2, day: 29),
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2025, month: 2, day: 28), calendar: calendar))
        XCTAssertEqual(next?.rule, .yearly(month: 2, day: 29))

        let following = RepeatPolicy.nextOccurrence(
            dueDate: next!.dueDate,
            reminderAt: next!.reminderAt,
            rule: next!.rule,
            calendar: calendar
        )
        XCTAssertEqual(following?.dueDate, CalendarDay.startOfDay(date(year: 2026, month: 2, day: 28), calendar: calendar))
    }

    func testYearlyKeepsMonthAndDay() {
        let next = RepeatPolicy.nextOccurrence(
            dueDate: date(year: 2026, month: 9, day: 15),
            reminderAt: nil,
            rule: .yearly(month: 9, day: 15),
            calendar: calendar
        )
        XCTAssertEqual(next?.dueDate, CalendarDay.startOfDay(date(year: 2027, month: 9, day: 15), calendar: calendar))
    }

    func testReminderShiftUsesCalendarDayAddingAcrossUSSpringForward() {
        let due = date(year: 2026, month: 3, day: 7, calendar: newYork)
        let reminder = date(year: 2026, month: 3, day: 7, hour: 9, minute: 30, calendar: newYork)
        let next = RepeatPolicy.nextOccurrence(
            dueDate: due,
            reminderAt: reminder,
            rule: .everyNDays(1),
            calendar: newYork
        )
        let parts = newYork.dateComponents([.year, .month, .day, .hour, .minute], from: next!.reminderAt!)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 3)
        XCTAssertEqual(parts.day, 8)
        XCTAssertEqual(parts.hour, 9)
        XCTAssertEqual(parts.minute, 30)
    }

    func testSummaryLabel() {
        XCTAssertEqual(RepeatPolicy.summaryLabel(intervalDays: 1), "Every day")
        XCTAssertEqual(RepeatPolicy.summaryLabel(intervalDays: 3), "Every 3 days")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.everyNDays(1)), "Every day")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.everyNDays(3)), "Every 3 days")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.weekdays(RepeatPolicy.mondayThroughFriday)), "Every weekday")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.weekdays(RepeatPolicy.weekendDays)), "Every weekend")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.weekdays([2, 4, 6])), "Mon, Wed, Fri")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.weekly), "Every week")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.monthly(dayOfMonth: 31)), "Every month")
        XCTAssertEqual(RepeatPolicy.summaryLabel(.yearly(month: 9, day: 15)), "Every year")
    }

    func testStoredFieldsRoundTripEveryKind() {
        let cases: [RecurrenceRule] = [
            .everyNDays(5),
            .weekdays([1, 7]),
            .weekly,
            .monthly(dayOfMonth: 31),
            .yearly(month: 2, day: 29)
        ]
        for rule in cases {
            let stored = RepeatPolicy.storedFields(from: rule)
            XCTAssertEqual(RepeatPolicy.rule(fromStored: stored), rule, "round-trip \(rule)")
        }
        XCTAssertNil(RepeatPolicy.rule(fromStored: RepeatPolicy.StoredFields()))
        XCTAssertEqual(
            RepeatPolicy.rule(fromStored: RepeatPolicy.StoredFields(intervalDays: 4)),
            .everyNDays(4)
        )
    }

    func testRulesMatchForDedupIgnoresWeekdaySetOrder() {
        XCTAssertTrue(RepeatPolicy.rulesMatch(.weekdays([2, 6]), .weekdays([6, 2])))
        XCTAssertFalse(RepeatPolicy.rulesMatch(.weekly, .everyNDays(7)))
        XCTAssertTrue(RepeatPolicy.rulesMatch(.monthly(dayOfMonth: 31), .monthly(dayOfMonth: 31)))
        XCTAssertFalse(RepeatPolicy.rulesMatch(.monthly(dayOfMonth: 31), .monthly(dayOfMonth: 28)))
    }

    func testLegacyIntervalOnlyFieldsStillDecodeAsEveryNDays() {
        let fields = RepeatPolicy.StoredFields(kindRaw: nil, intervalDays: 2, weekdaysMask: 0, monthDay: nil, month: nil)
        XCTAssertEqual(RepeatPolicy.rule(fromStored: fields), .everyNDays(2))
    }

    private func date(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        let cal = calendar ?? self.calendar
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return cal.date(from: components)!
    }
}
