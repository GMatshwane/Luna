import CoreText
import SwiftUI

enum LunaTypography {
    enum Weight {
        case regular
        case medium
        case semibold

        var postScriptName: String {
            switch self {
            case .regular:
                return "Roboto-Regular"
            case .medium:
                return "Roboto-Medium"
            case .semibold:
                return "Roboto-SemiBold"
            }
        }
    }

    static func font(_ style: Font.TextStyle, weight: Weight = .regular) -> Font {
        registerIfNeeded()
        return Font.custom(weight.postScriptName, size: pointSize(for: style), relativeTo: style)
    }

    static func font(size: CGFloat, relativeTo style: Font.TextStyle, weight: Weight = .regular) -> Font {
        registerIfNeeded()
        return Font.custom(weight.postScriptName, size: size, relativeTo: style)
    }

    static func tabular(_ style: Font.TextStyle, weight: Weight = .regular) -> Font {
        font(style, weight: weight).monospacedDigit()
    }

    static func pointSize(for style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: return 34
        case .title: return 28
        case .title2: return 22
        case .title3: return 20
        case .headline: return 17
        case .body: return 17
        case .callout: return 16
        case .subheadline: return 15
        case .footnote: return 13
        case .caption: return 12
        case .caption2: return 11
        @unknown default: return 17
        }
    }

    static func registerIfNeeded() {
        _ = registration
    }

    private static let registration: Void = {
        for name in ["Roboto-Regular", "Roboto-Medium", "Roboto-SemiBold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }()
}
