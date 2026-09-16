import XCTest
@testable import Luna

final class LunaTypographyTests: XCTestCase {
    func testRobotoPostScriptNames() {
        XCTAssertEqual(LunaTypography.Weight.regular.postScriptName, "Roboto-Regular")
        XCTAssertEqual(LunaTypography.Weight.medium.postScriptName, "Roboto-Medium")
        XCTAssertEqual(LunaTypography.Weight.semibold.postScriptName, "Roboto-SemiBold")
    }

    func testDefaultPointSizesMatchDynamicTypeTextStyles() {
        XCTAssertEqual(LunaTypography.pointSize(for: .largeTitle), 34)
        XCTAssertEqual(LunaTypography.pointSize(for: .title), 28)
        XCTAssertEqual(LunaTypography.pointSize(for: .title2), 22)
        XCTAssertEqual(LunaTypography.pointSize(for: .title3), 20)
        XCTAssertEqual(LunaTypography.pointSize(for: .headline), 17)
        XCTAssertEqual(LunaTypography.pointSize(for: .body), 17)
        XCTAssertEqual(LunaTypography.pointSize(for: .callout), 16)
        XCTAssertEqual(LunaTypography.pointSize(for: .subheadline), 15)
        XCTAssertEqual(LunaTypography.pointSize(for: .footnote), 13)
        XCTAssertEqual(LunaTypography.pointSize(for: .caption), 12)
        XCTAssertEqual(LunaTypography.pointSize(for: .caption2), 11)
    }

    func testFontFilesAreBundled() {
        for name in ["Roboto-Regular", "Roboto-Medium", "Roboto-SemiBold"] {
            let url = Bundle.main.url(forResource: name, withExtension: "ttf")
            XCTAssertNotNil(url, "Missing bundled font \(name).ttf")
        }
    }
}
