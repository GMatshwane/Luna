import Foundation

enum ScorePolicy {
    static let defaultPoints = 1
    static let minimumPoints = 1
    static let maximumPoints = 99
    static let defaultDailyGoal = 10
    static let minimumDailyGoal = 1
    static let maximumDailyGoal = 999

    struct DayScore: Equatable {
        var earned: Int
        var goal: Int

        var progress: Double {
            guard goal > 0 else { return 0 }
            min(1, Double(earned) / Double(goal))
        }

        var label: String { "\(earned) / \(goal)" }

        var isMet: Bool { earned >= goal }
    }

    static func normalizedPoints(_ points: Int) -> Int {
        min(max(points, minimumPoints), maximumPoints)
    }

    static func normalizedGoal(_ goal: Int) -> Int {
        min(max(goal, minimumDailyGoal), maximumDailyGoal)
    }

    static func earnedPoints<T>(from items: [T], points: (T) -> Int, isCompleted: (T) -> Bool) -> Int {
        items.reduce(0) { total, item in
            total + (isCompleted(item) ? normalizedPoints(points(item)) : 0)
        }
    }

    static func score(earned: Int, goal: Int) -> DayScore {
        DayScore(earned: max(0, earned), goal: normalizedGoal(goal))
    }
}
