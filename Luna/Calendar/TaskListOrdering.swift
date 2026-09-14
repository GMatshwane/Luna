import Foundation

struct TaskSortKey: Equatable {
    var reminderAt: Date?
    var sortOrder: Int
    var createdAt: Date
}

enum TaskListOrdering {
    static func lessThan(_ lhs: TaskSortKey, _ rhs: TaskSortKey) -> Bool {
        switch (lhs.reminderAt, rhs.reminderAt) {
        case let (left?, right?) where left != right:
            return left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }

        if lhs.sortOrder != rhs.sortOrder {
            return lhs.sortOrder < rhs.sortOrder
        }
        return lhs.createdAt < rhs.createdAt
    }

    static func sorted<T>(_ items: [T], key: (T) -> TaskSortKey) -> [T] {
        items.sorted { lessThan(key($0), key($1)) }
    }
}
