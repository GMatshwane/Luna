import SwiftUI
import UIKit

enum LunaTheme {
    struct Palette: Equatable {
        let background: UInt32
        let surface: UInt32
        let border: UInt32
        let secondary: UInt32
        let highlight: UInt32

        var backgroundHex: String { Self.hexString(background) }
        var surfaceHex: String { Self.hexString(surface) }
        var borderHex: String { Self.hexString(border) }
        var secondaryHex: String { Self.hexString(secondary) }
        var highlightHex: String { Self.hexString(highlight) }

        static let dark = Palette(
            background: 0x011C40,
            surface: 0x023859,
            border: 0x26658C,
            secondary: 0x54ACBF,
            highlight: 0xA7EBF2
        )

        static let light = Palette(
            background: 0xEAF8FA,
            surface: 0xFFFFFF,
            border: 0x54ACBF,
            secondary: 0x26658C,
            highlight: 0x011C40
        )

        private static func hexString(_ value: UInt32) -> String {
            String(format: "#%06X", value)
        }
    }

    static let background = Color(light: Palette.light.background, dark: Palette.dark.background)
    static let surface = Color(light: Palette.light.surface, dark: Palette.dark.surface)
    static let border = Color(light: Palette.light.border, dark: Palette.dark.border)
    static let secondary = Color(light: Palette.light.secondary, dark: Palette.dark.secondary)
    static let highlight = Color(light: Palette.light.highlight, dark: Palette.dark.highlight)

    static let backgroundHex = Palette.dark.backgroundHex
    static let surfaceHex = Palette.dark.surfaceHex
    static let borderHex = Palette.dark.borderHex
    static let secondaryHex = Palette.dark.secondaryHex
    static let highlightHex = Palette.dark.highlightHex
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }

    init(light: UInt32, dark: UInt32, alpha: Double = 1) {
        self.init(
            uiColor: UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255,
                    green: CGFloat((hex >> 8) & 0xFF) / 255,
                    blue: CGFloat(hex & 0xFF) / 255,
                    alpha: alpha
                )
            }
        )
    }
}

extension View {
    func lunaScreen() -> some View {
        self
            .tint(LunaTheme.highlight)
            .background(LunaTheme.background.ignoresSafeArea())
    }
}
