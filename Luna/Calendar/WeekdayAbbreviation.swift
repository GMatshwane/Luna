import Foundation

enum WeekdayAbbreviation {
    static func compact(_ date: Date, locale: Locale = .autoupdatingCurrent) -> String {
        var style = Date.FormatStyle().weekday(.abbreviated)
        style.locale = locale
        return date.formatted(style)
    }
}
