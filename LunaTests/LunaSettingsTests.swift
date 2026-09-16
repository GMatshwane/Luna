import XCTest
import SwiftUI
@testable import Luna

@MainActor
final class LunaSettingsTests: XCTestCase {
    func testAppearanceDefaultsToSystem() {
        let suite = "luna.tests.appearance.default"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let settings = LunaSettings(defaults: defaults)
        XCTAssertEqual(settings.appearance, .system)
    }

    func testAppearancePersistsInUserDefaults() {
        let suite = "luna.tests.appearance.persist"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let settings = LunaSettings(defaults: defaults)
        settings.appearance = .light
        XCTAssertEqual(defaults.string(forKey: LunaSettings.appearanceKey), "light")

        let reloaded = LunaSettings(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, .light)
    }

    func testInvalidStoredAppearanceFallsBackToSystem() {
        let suite = "luna.tests.appearance.invalid"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        defaults.set("sepia", forKey: LunaSettings.appearanceKey)

        let settings = LunaSettings(defaults: defaults)
        XCTAssertEqual(settings.appearance, .system)
    }

    func testPreferredColorSchemeMapping() {
        XCTAssertNil(LunaAppearance.system.preferredColorScheme)
        XCTAssertEqual(LunaAppearance.light.preferredColorScheme, .light)
        XCTAssertEqual(LunaAppearance.dark.preferredColorScheme, .dark)
    }
}
