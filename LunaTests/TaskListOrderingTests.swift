import XCTest
@testable import Luna

final class TaskListOrderingTests: XCTestCase {
    func testTimedTasksComeBeforeUntimed() {
        let untimed = TaskSortKey(reminderAt: nil, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 1))
        let timed = TaskSortKey(reminderAt: Date(timeIntervalSince1970: 50), sortOrder: 0, createdAt: Date(timeIntervalSince1970: 2))
        XCTAssertTrue(TaskListOrdering.lessThan(timed, untimed))
        XCTAssertFalse(TaskListOrdering.lessThan(untimed, timed))
    }

    func testTimedTasksSortByReminderTime() {
        let later = TaskSortKey(reminderAt: Date(timeIntervalSince1970: 200), sortOrder: 0, createdAt: Date(timeIntervalSince1970: 1))
        let earlier = TaskSortKey(reminderAt: Date(timeIntervalSince1970: 100), sortOrder: 0, createdAt: Date(timeIntervalSince1970: 2))
        XCTAssertTrue(TaskListOrdering.lessThan(earlier, later))
    }

    func testUntimedTieBreaksOnSortOrderThenCreatedAt() {
        let first = TaskSortKey(reminderAt: nil, sortOrder: 1, createdAt: Date(timeIntervalSince1970: 20))
        let second = TaskSortKey(reminderAt: nil, sortOrder: 2, createdAt: Date(timeIntervalSince1970: 1))
        XCTAssertTrue(TaskListOrdering.lessThan(first, second))

        let older = TaskSortKey(reminderAt: nil, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 1))
        let newer = TaskSortKey(reminderAt: nil, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 2))
        XCTAssertTrue(TaskListOrdering.lessThan(older, newer))
    }

    func testSortedHelperPreservesRelativeOrderRules() {
        let keys = [
            TaskSortKey(reminderAt: nil, sortOrder: 0, createdAt: Date(timeIntervalSince1970: 1)),
            TaskSortKey(reminderAt: Date(timeIntervalSince1970: 30), sortOrder: 0, createdAt: Date(timeIntervalSince1970: 2)),
            TaskSortKey(reminderAt: Date(timeIntervalSince1970: 10), sortOrder: 0, createdAt: Date(timeIntervalSince1970: 3))
        ]
        let sorted = TaskListOrdering.sorted(keys) { $0 }
        XCTAssertEqual(sorted.map(\.reminderAt), [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 30),
            nil
        ])
    }
}
