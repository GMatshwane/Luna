import SwiftData

enum LunaPersistence {
    static func makeContainer(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([TaskItem.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create Luna store: \(error)")
        }
    }
}
