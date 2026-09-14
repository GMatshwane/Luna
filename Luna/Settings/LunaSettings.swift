import Foundation
import Observation

@Observable
@MainActor
final class LunaSettings {
    static let dailyPointGoalKey = "luna.dailyPointGoal"

    private let defaults: UserDefaults
    var dailyPointGoal: Int {
        didSet {
            let normalized = ScorePolicy.normalizedGoal(dailyPointGoal)
            defaults.set(normalized, forKey: Self.dailyPointGoalKey)
            if dailyPointGoal != normalized {
                dailyPointGoal = normalized
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.dailyPointGoalKey) as? Int
        self.dailyPointGoal = ScorePolicy.normalizedGoal(stored ?? ScorePolicy.defaultDailyGoal)
    }
}
