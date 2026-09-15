import XCTest
@testable import Luna

final class CategoryPolicyTests: XCTestCase {
    func testBlankNamesAreRejectedAndWhitespaceIsTrimmed() {
        XCTAssertNil(CategoryPolicy.normalizedName(""))
        XCTAssertNil(CategoryPolicy.normalizedName("   "))
        XCTAssertEqual(CategoryPolicy.normalizedName("  Health  "), "Health")
    }

    func testNameIsClampedToMaximumLength() {
        let overflow = String(repeating: "a", count: CategoryPolicy.maximumNameLength + 5)
        let normalized = CategoryPolicy.normalizedName(overflow)
        XCTAssertEqual(normalized?.count, CategoryPolicy.maximumNameLength)
    }

    func testNamesMatchCaseInsensitively() {
        XCTAssertTrue(CategoryPolicy.namesMatch("Health", "health"))
        XCTAssertFalse(CategoryPolicy.namesMatch("Health", "Home"))
        XCTAssertFalse(CategoryPolicy.namesMatch("  ", "Health"))
    }

    func testColorHexNormalizesHashAndLowercase() {
        XCTAssertEqual(CategoryPolicy.normalizedColorHex("#c97b84"), "C97B84")
        XCTAssertEqual(CategoryPolicy.normalizedColorHex("a3b18a"), "A3B18A")
        XCTAssertNil(CategoryPolicy.normalizedColorHex(nil))
        XCTAssertNil(CategoryPolicy.normalizedColorHex(""))
        XCTAssertNil(CategoryPolicy.normalizedColorHex("zzz"))
        XCTAssertNil(CategoryPolicy.normalizedColorHex("#FFF"))
    }

    func testFilterMatchesAllUncategorizedAndIdentified() {
        let healthID = UUID()
        let rows = [
            Sample(title: "Stretch", categoryID: healthID),
            Sample(title: "Inbox", categoryID: nil)
        ]

        XCTAssertEqual(
            rows.filter { CategoryPolicy.matches($0, filter: .all, categoryID: { $0.categoryID }) }.map(\.title),
            ["Stretch", "Inbox"]
        )
        XCTAssertEqual(
            rows.filter { CategoryPolicy.matches($0, filter: .uncategorized, categoryID: { $0.categoryID }) }.map(\.title),
            ["Inbox"]
        )
        XCTAssertEqual(
            rows.filter { CategoryPolicy.matches($0, filter: .identified(healthID), categoryID: { $0.categoryID }) }.map(\.title),
            ["Stretch"]
        )
    }

    func testGroupedSectionsSortNamedCategoriesThenUncategorized() {
        let healthID = UUID()
        let homeID = UUID()
        let earlier = Date(timeIntervalSince1970: 10)
        let later = Date(timeIntervalSince1970: 20)
        let rows = [
            Sample(title: "Unsorted", categoryID: nil, categoryName: nil, createdAt: later, sortOrder: 0),
            Sample(title: "Water plants", categoryID: homeID, categoryName: "Home", colorHex: "#d4a373", createdAt: later, sortOrder: 1),
            Sample(title: "Stretch", categoryID: healthID, categoryName: "Health", colorHex: "c97b84", createdAt: earlier, sortOrder: 0),
            Sample(title: "Walk", categoryID: healthID, categoryName: "Health", colorHex: "c97b84", createdAt: later, sortOrder: 1)
        ]

        let sections = CategoryPolicy.grouped(
            rows,
            filter: .all,
            categoryID: { $0.categoryID },
            categoryName: { $0.categoryName },
            colorHex: { $0.colorHex },
            sortKey: { $0.sortKey }
        )

        XCTAssertEqual(sections.map(\.name), ["Health", "Home", CategoryPolicy.uncategorizedName])
        XCTAssertEqual(sections.map(\.categoryID), [healthID, homeID, nil])
        XCTAssertEqual(sections[0].tasks.map(\.title), ["Stretch", "Walk"])
        XCTAssertEqual(sections[1].colorHex, "D4A373")
        XCTAssertEqual(sections[2].tasks.map(\.title), ["Unsorted"])
    }

    func testGroupedHonorsFilterAndKeepsReminderOrderingInsideASection() {
        let healthID = UUID()
        let rows = [
            Sample(
                title: "Later reminder",
                categoryID: healthID,
                categoryName: "Health",
                reminderAt: Date(timeIntervalSince1970: 200),
                createdAt: Date(timeIntervalSince1970: 1)
            ),
            Sample(
                title: "Earlier reminder",
                categoryID: healthID,
                categoryName: "Health",
                reminderAt: Date(timeIntervalSince1970: 50),
                createdAt: Date(timeIntervalSince1970: 2)
            ),
            Sample(title: "Inbox", categoryID: nil, createdAt: Date(timeIntervalSince1970: 3))
        ]

        let healthOnly = CategoryPolicy.grouped(
            rows,
            filter: .identified(healthID),
            categoryID: { $0.categoryID },
            categoryName: { $0.categoryName },
            colorHex: { $0.colorHex },
            sortKey: { $0.sortKey }
        )
        XCTAssertEqual(healthOnly.map(\.name), ["Health"])
        XCTAssertEqual(healthOnly[0].tasks.map(\.title), ["Earlier reminder", "Later reminder"])

        let uncategorized = CategoryPolicy.grouped(
            rows,
            filter: .uncategorized,
            categoryID: { $0.categoryID },
            categoryName: { $0.categoryName },
            colorHex: { $0.colorHex },
            sortKey: { $0.sortKey }
        )
        XCTAssertEqual(uncategorized.map(\.categoryID), [nil])
        XCTAssertEqual(uncategorized[0].tasks.map(\.title), ["Inbox"])
    }

    func testSectionsAppearOnlyWhenATaskHasACategory() {
        let plain = [Sample(title: "Inbox", categoryID: nil)]
        XCTAssertFalse(CategoryPolicy.shouldShowSections(plain, categoryID: { $0.categoryID }))

        let mixed = [
            Sample(title: "Inbox", categoryID: nil),
            Sample(title: "Stretch", categoryID: UUID())
        ]
        XCTAssertTrue(CategoryPolicy.shouldShowSections(mixed, categoryID: { $0.categoryID }))
    }

    private struct Sample {
        var title: String
        var categoryID: UUID?
        var categoryName: String?
        var colorHex: String?
        var reminderAt: Date?
        var createdAt: Date
        var sortOrder: Int

        init(
            title: String,
            categoryID: UUID?,
            categoryName: String? = nil,
            colorHex: String? = nil,
            reminderAt: Date? = nil,
            createdAt: Date = Date(timeIntervalSince1970: 1),
            sortOrder: Int = 0
        ) {
            self.title = title
            self.categoryID = categoryID
            self.categoryName = categoryName
            self.colorHex = colorHex
            self.reminderAt = reminderAt
            self.createdAt = createdAt
            self.sortOrder = sortOrder
        }

        var sortKey: TaskSortKey {
            TaskSortKey(reminderAt: reminderAt, sortOrder: sortOrder, createdAt: createdAt)
        }
    }
}
