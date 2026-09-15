import Foundation

enum CategoryPolicy {
    static let uncategorizedName = "Uncategorized"
    static let maximumNameLength = 40
    static let suggestedColorHexes = [
        "C97B84",
        "D4A373",
        "A3B18A",
        "7B8CDE",
        "C9A0DC",
        "E8D5B7"
    ]

    enum Filter: Equatable {
        case all
        case uncategorized
        case identified(UUID)
    }

    struct Section<Task> {
        var categoryID: UUID?
        var name: String
        var colorHex: String?
        var tasks: [Task]
    }

    static func normalizedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.count <= maximumNameLength {
            return trimmed
        }
        let end = trimmed.index(trimmed.startIndex, offsetBy: maximumNameLength)
        return String(trimmed[..<end])
    }

    static func namesMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard let left = normalizedName(lhs), let right = normalizedName(rhs) else { return false }
        return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    static func normalizedColorHex(_ hex: String?) -> String? {
        guard let value = parseColorHex(hex) else { return nil }
        return String(format: "%06X", value)
    }

    static func parseColorHex(_ hex: String?) -> UInt32? {
        guard let hex else { return nil }
        var trimmed = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if trimmed.hasPrefix("#") {
            trimmed.removeFirst()
        }
        guard trimmed.count == 6, trimmed.allSatisfy(\.isHexDigit) else { return nil }
        return UInt32(trimmed, radix: 16)
    }

    static func matches<Task>(
        _ task: Task,
        filter: Filter,
        categoryID: (Task) -> UUID?
    ) -> Bool {
        switch filter {
        case .all:
            return true
        case .uncategorized:
            return categoryID(task) == nil
        case .identified(let id):
            return categoryID(task) == id
        }
    }

    static func shouldShowSections<Task>(_ tasks: [Task], categoryID: (Task) -> UUID?) -> Bool {
        tasks.contains { categoryID($0) != nil }
    }

    static func grouped<Task>(
        _ tasks: [Task],
        filter: Filter = .all,
        categoryID: (Task) -> UUID?,
        categoryName: (Task) -> String?,
        colorHex: (Task) -> String?,
        sortKey: (Task) -> TaskSortKey
    ) -> [Section<Task>] {
        let filtered = tasks.filter { matches($0, filter: filter, categoryID: categoryID) }
        let ordered = TaskListOrdering.sorted(filtered, key: sortKey)

        var buckets: [UUID?: (name: String, colorHex: String?, tasks: [Task])] = [:]
        var seenNamed: [UUID] = []

        for task in ordered {
            let id = categoryID(task)
            if var bucket = buckets[id] {
                bucket.tasks.append(task)
                buckets[id] = bucket
                continue
            }

            if let id {
                seenNamed.append(id)
                buckets[id] = (
                    categoryName(task).flatMap(normalizedName) ?? uncategorizedName,
                    normalizedColorHex(colorHex(task)),
                    [task]
                )
            } else {
                buckets[nil] = (uncategorizedName, nil, [task])
            }
        }

        var sections = seenNamed.compactMap { id -> Section<Task>? in
            guard let bucket = buckets[id] else { return nil }
            return Section(categoryID: id, name: bucket.name, colorHex: bucket.colorHex, tasks: bucket.tasks)
        }
        sections.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if let uncategorized = buckets[nil] {
            sections.append(
                Section(categoryID: nil, name: uncategorized.name, colorHex: nil, tasks: uncategorized.tasks)
            )
        }
        return sections
    }
}
