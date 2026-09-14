import SwiftUI

enum LunaTheme {
    static let background = Color(hex: 0x011C40)
    static let surface = Color(hex: 0x023859)
    static let border = Color(hex: 0x26658C)
    static let secondary = Color(hex: 0x54ACBF)
    static let highlight = Color(hex: 0xA7EBF2)

    static let backgroundHex = "#011C40"
    static let surfaceHex = "#023859"
    static let borderHex = "#26658C"
    static let secondaryHex = "#54ACBF"
    static let highlightHex = "#A7EBF2"
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
}

extension View {
    func lunaScreen() -> some View {
        self
            .tint(LunaTheme.highlight)
            .background(LunaTheme.background.ignoresSafeArea())
            .preferredColorScheme(.dark)
    }
}
