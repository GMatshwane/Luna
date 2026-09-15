import Foundation
import Observation
import SwiftUI

enum LunaAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
@MainActor
final class LunaSettings {
    static let dailyPointGoalKey = "luna.dailyPointGoal"
    static let appearanceKey = "luna.appearance"

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

    var appearance: LunaAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: Self.appearanceKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.object(forKey: Self.dailyPointGoalKey) as? Int
        self.dailyPointGoal = ScorePolicy.normalizedGoal(stored ?? ScorePolicy.defaultDailyGoal)
        let storedAppearance = defaults.string(forKey: Self.appearanceKey) ?? ""
        self.appearance = LunaAppearance(rawValue: storedAppearance) ?? .system
    }
}
