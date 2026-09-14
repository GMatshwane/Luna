import XCTest
@testable import Luna

final class ReminderPolicyTests: XCTestCase {
    private let taskID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!

    func testDoesNotScheduleWhenReminderMissing() {
        XCTAssertFalse(ReminderPolicy.shouldSchedule(reminderAt: nil, isCompleted: false, now: Date(timeIntervalSince1970: 10)))
    }

    func testDoesNotScheduleWhenCompleted() {
        let future = Date(timeIntervalSince1970: 50)
        XCTAssertFalse(ReminderPolicy.shouldSchedule(reminderAt: future, isCompleted: true, now: Date(timeIntervalSince1970: 10)))
    }

    func testDoesNotScheduleWhenReminderIsPastOrNow() {
        let now = Date(timeIntervalSince1970: 20)
        XCTAssertFalse(ReminderPolicy.shouldSchedule(reminderAt: now, isCompleted: false, now: now))
        XCTAssertFalse(ReminderPolicy.shouldSchedule(reminderAt: Date(timeIntervalSince1970: 19), isCompleted: false, now: now))
    }

    func testSchedulesFutureIncompleteReminder() {
        let now = Date(timeIntervalSince1970: 20)
        XCTAssertTrue(ReminderPolicy.shouldSchedule(reminderAt: Date(timeIntervalSince1970: 21), isCompleted: false, now: now))
    }

    func testNotificationIdentifierIncludesTaskID() {
        XCTAssertEqual(
            ReminderPolicy.notificationIdentifier(taskID: taskID),
            "luna.task.AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"
        )
    }

    func testUserInfoPayloadIncludesTaskID() {
        let info = ReminderPolicy.userInfo(taskID: taskID)
        XCTAssertEqual(info[ReminderPolicy.taskIDKey] as? String, taskID.uuidString)
    }

    func testBodyFallsBackWhenNotesEmpty() {
        XCTAssertEqual(ReminderPolicy.body(notes: nil), "Luna reminder")
        XCTAssertEqual(ReminderPolicy.body(notes: "  "), "Luna reminder")
        XCTAssertEqual(ReminderPolicy.body(notes: "Bring keys"), "Bring keys")
    }
}
