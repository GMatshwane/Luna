import XCTest
@testable import Luna

final class LunaThemeTests: XCTestCase {
    func testDarkPaletteKeepsOriginalHierarchy() {
        let palette = LunaTheme.Palette.dark
        XCTAssertEqual(palette.backgroundHex, "#011C40")
        XCTAssertEqual(palette.surfaceHex, "#023859")
        XCTAssertEqual(palette.borderHex, "#26658C")
        XCTAssertEqual(palette.secondaryHex, "#54ACBF")
        XCTAssertEqual(palette.highlightHex, "#A7EBF2")
    }

    func testLightPaletteUsesSameTokenHierarchy() {
        let palette = LunaTheme.Palette.light
        XCTAssertEqual(palette.backgroundHex, "#EAF8FA")
        XCTAssertEqual(palette.surfaceHex, "#FFFFFF")
        XCTAssertEqual(palette.borderHex, "#54ACBF")
        XCTAssertEqual(palette.secondaryHex, "#26658C")
        XCTAssertEqual(palette.highlightHex, "#011C40")
    }

    func testPublishedHexesMatchDarkPalette() {
        XCTAssertEqual(LunaTheme.backgroundHex, LunaTheme.Palette.dark.backgroundHex)
        XCTAssertEqual(LunaTheme.surfaceHex, LunaTheme.Palette.dark.surfaceHex)
        XCTAssertEqual(LunaTheme.borderHex, LunaTheme.Palette.dark.borderHex)
        XCTAssertEqual(LunaTheme.secondaryHex, LunaTheme.Palette.dark.secondaryHex)
        XCTAssertEqual(LunaTheme.highlightHex, LunaTheme.Palette.dark.highlightHex)
    }
}
