import Foundation
import SwiftUI
import Testing
import UIKit
@testable import tyfe_ios_app

struct FocusDaypartTests {

    struct BoundaryCase: Sendable {
        let hour: Int
        let minute: Int
        let expected: FocusDaypart
    }

    struct VisualStyleCase: Sendable {
        let daypart: FocusDaypart
        let cardFill: String
        let cardBorder: String
        let accentFill: String
        let backgroundForeground: String
        let backgroundBase: String
        let backgroundHighlight: String
        let backgroundDepth: String
    }

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    @Test(arguments: [
        BoundaryCase(hour: 5, minute: 59, expected: .night),
        BoundaryCase(hour: 6, minute: 0, expected: .morning),
        BoundaryCase(hour: 11, minute: 59, expected: .morning),
        BoundaryCase(hour: 12, minute: 0, expected: .midday),
        BoundaryCase(hour: 14, minute: 59, expected: .midday),
        BoundaryCase(hour: 15, minute: 0, expected: .afternoon),
        BoundaryCase(hour: 17, minute: 59, expected: .afternoon),
        BoundaryCase(hour: 18, minute: 0, expected: .night),
        BoundaryCase(hour: 23, minute: 59, expected: .night),
        BoundaryCase(hour: 0, minute: 0, expected: .night)
    ])
    func resolvesDaypartAtBoundaries(boundary: BoundaryCase) {
        let date = date(hour: boundary.hour, minute: boundary.minute, calendar: utcCalendar)

        #expect(FocusDaypart(date: date, calendar: utcCalendar) == boundary.expected)
    }

    @Test func resolvesUsingTheProvidedTimezone() {
        let instant = date(hour: 2, minute: 0, calendar: utcCalendar)
        var jakartaCalendar = Calendar(identifier: .gregorian)
        jakartaCalendar.timeZone = TimeZone(identifier: "Asia/Jakarta") ?? .current

        #expect(FocusDaypart(date: instant, calendar: utcCalendar) == .night)
        #expect(FocusDaypart(date: instant, calendar: jakartaCalendar) == .morning)
    }

    @Test func nextRefreshAlignsToTheNextMinute() {
        let date = date(hour: 11, minute: 59, second: 42, calendar: utcCalendar)
        let nextRefresh = FocusDaypart.nextMinuteBoundary(after: date, calendar: utcCalendar)
        let components = utcCalendar.dateComponents([.hour, .minute, .second], from: nextRefresh)

        #expect(components.hour == 12)
        #expect(components.minute == 0)
        #expect(components.second == 0)
    }

    @Test func exposesDaypartGreetings() {
        #expect(FocusDaypart.morning.greeting == "Good Morning")
        #expect(FocusDaypart.midday.greeting == "Good Afternoon")
        #expect(FocusDaypart.afternoon.greeting == "Good Afternoon")
        #expect(FocusDaypart.night.greeting == "Good Evening")
        #expect(FocusDaypart.midday.symbolName == "cloud.sun.fill")
    }

    @Test func daytimeUsesVerticalWhiteFadeWhileNightKeepsLayeredBackground() {
        #expect(FocusDaypart.morning.usesVerticalWhiteFade)
        #expect(FocusDaypart.midday.usesVerticalWhiteFade)
        #expect(FocusDaypart.afternoon.usesVerticalWhiteFade)
        #expect(!FocusDaypart.night.usesVerticalWhiteFade)
    }

    @Test(arguments: [
        VisualStyleCase(
            daypart: .morning,
            cardFill: "173F62",
            cardBorder: "72B7D9",
            accentFill: "FFE49A",
            backgroundForeground: "1E201C",
            backgroundBase: "5EA9D0",
            backgroundHighlight: "A8DDF0",
            backgroundDepth: "62A8C8"
        ),
        VisualStyleCase(
            daypart: .midday,
            cardFill: "173F62",
            cardBorder: "72B7D9",
            accentFill: "FFE49A",
            backgroundForeground: "1E201C",
            backgroundBase: "5EA9D0",
            backgroundHighlight: "A8DDF0",
            backgroundDepth: "62A8C8"
        ),
        VisualStyleCase(
            daypart: .afternoon,
            cardFill: "5B3027",
            cardBorder: "E0A454",
            accentFill: "FFE1A3",
            backgroundForeground: "F7F7F2",
            backgroundBase: "8D452C",
            backgroundHighlight: "E0A454",
            backgroundDepth: "A95745"
        ),
        VisualStyleCase(
            daypart: .night,
            cardFill: "111A36",
            cardBorder: "6F86B6",
            accentFill: "DCE7FF",
            backgroundForeground: "F7F7F2",
            backgroundBase: "0C1738",
            backgroundHighlight: "31558C",
            backgroundDepth: "26345F"
        )
    ])
    func exposesExpectedVisualTokens(testCase: VisualStyleCase) {
        let style = testCase.daypart.visualStyle

        #expect(hex(style.cardFill) == testCase.cardFill)
        #expect(hex(style.cardBorder) == testCase.cardBorder)
        #expect(hex(style.accentFill) == testCase.accentFill)
        #expect(hex(style.backgroundForeground) == testCase.backgroundForeground)
        #expect(hex(testCase.daypart.palette.base) == testCase.backgroundBase)
        #expect(hex(testCase.daypart.palette.highlight) == testCase.backgroundHighlight)
        #expect(hex(testCase.daypart.palette.depth) == testCase.backgroundDepth)
    }

    @Test(arguments: FocusDaypart.allCases)
    func visualStyleMaintainsRequiredContrast(daypart: FocusDaypart) {
        let style = daypart.visualStyle

        #expect(contrastRatio(style.primaryForeground, style.cardFill) >= 4.5)
        #expect(contrastRatio(style.secondaryForeground, style.cardFill) >= 4.5)
        #expect(contrastRatio(style.accentForeground, style.accentFill) >= 4.5)
        #expect(contrastRatio(style.cardBorder, style.cardFill) >= 3)
        if daypart == .morning || daypart == .midday {
            #expect(contrastRatio(style.backgroundForeground, daypart.palette.base) >= 4.5)
            #expect(contrastRatio(style.backgroundForeground, daypart.palette.highlight) >= 4.5)
            #expect(contrastRatio(style.backgroundForeground, daypart.palette.depth) >= 4.5)
        }
    }

    private func date(
        hour: Int,
        minute: Int,
        second: Int = 0,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 9,
            day: 16,
            hour: hour,
            minute: minute,
            second: second
        )) ?? Date(timeIntervalSince1970: 0)
    }

    private func hex(_ color: Color) -> String {
        let resolved = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "%02lX%02lX%02lX",
            lroundf(Float(red) * 255),
            lroundf(Float(green) * 255),
            lroundf(Float(blue) * 255)
        )
    }

    private func contrastRatio(_ foreground: Color, _ background: Color) -> CGFloat {
        let foregroundLuminance = relativeLuminance(UIColor(foreground))
        let backgroundLuminance = relativeLuminance(UIColor(background))
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> CGFloat {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        func linearize(_ component: CGFloat) -> CGFloat {
            component <= 0.04045
                ? component / 12.92
                : pow((component + 0.055) / 1.055, 2.4)
        }

        return (0.2126 * linearize(red))
            + (0.7152 * linearize(green))
            + (0.0722 * linearize(blue))
    }
}
