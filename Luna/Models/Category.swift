import Foundation
import SwiftData

@Model
final class Category {
    var id: UUID
    var name: String
    var colorHex: String?
    var createdAt: Date
    var sortOrder: Int
    @Relationship(deleteRule: .nullify, inverse: \TaskItem.category)
    var tasks: [TaskItem] = []

    init(
        id: UUID = UUID(),
        name: String,
        colorHex: String? = nil,
        createdAt: Date = .now,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = CategoryPolicy.normalizedName(name) ?? "Category"
        self.colorHex = CategoryPolicy.normalizedColorHex(colorHex)
        self.createdAt = createdAt
        self.sortOrder = sortOrder
        self.tasks = []
    }
}
