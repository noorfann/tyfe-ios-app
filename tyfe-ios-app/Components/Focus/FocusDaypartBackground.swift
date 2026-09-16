import SwiftUI

enum FocusDaypart: CaseIterable, Hashable, Sendable {
    case morning
    case afternoon
    case night

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        switch calendar.component(.hour, from: date) {
        case 6..<12:
            self = .morning
        case 12..<18:
            self = .afternoon
        default:
            self = .night
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .afternoon: return "cloud.sun.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var greeting: String {
        switch self {
        case .morning: return "Good Morning"
        case .afternoon: return "Good Afternoon"
        case .night: return "Good Evening"
        }
    }

    var foreground: Color {
        visualStyle.primaryForeground
    }

    var symbolColor: Color {
        visualStyle.accentFill
    }

    var visualStyle: FocusDaypartVisualStyle {
        switch self {
        case .morning:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "173F62"),
                cardBorder: Color(hex: "72B7D9"),
                primaryForeground: Color(hex: "F7F7F2"),
                secondaryForeground: Color(hex: "C7D9E5"),
                accentFill: Color(hex: "FFE49A"),
                accentForeground: Color(hex: "1E201C")
            )
        case .afternoon:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "5B3027"),
                cardBorder: Color(hex: "E0A454"),
                primaryForeground: Color(hex: "F7F7F2"),
                secondaryForeground: Color(hex: "E7CEC6"),
                accentFill: Color(hex: "FFE1A3"),
                accentForeground: Color(hex: "1E201C")
            )
        case .night:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "111A36"),
                cardBorder: Color(hex: "6F86B6"),
                primaryForeground: Color(hex: "F7F7F2"),
                secondaryForeground: Color(hex: "C8D1E8"),
                accentFill: Color(hex: "DCE7FF"),
                accentForeground: Color(hex: "1E201C")
            )
        }
    }

    static func nextMinuteBoundary(
        after date: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> Date {
        let minuteStart = calendar.dateInterval(of: .minute, for: date)?.start ?? date
        return calendar.date(byAdding: .minute, value: 1, to: minuteStart)
            ?? date.addingTimeInterval(60)
    }

    fileprivate var palette: FocusDaypartPalette {
        switch self {
        case .morning:
            FocusDaypartPalette(
                base: Color(hex: "245A8D"),
                highlight: Color(hex: "72B7D9"),
                depth: Color(hex: "287D9C")
            )
        case .afternoon:
            FocusDaypartPalette(
                base: Color(hex: "8D452C"),
                highlight: Color(hex: "E0A454"),
                depth: Color(hex: "A95745")
            )
        case .night:
            FocusDaypartPalette(
                base: Color(hex: "0C1738"),
                highlight: Color(hex: "31558C"),
                depth: Color(hex: "26345F")
            )
        }
    }
}

struct FocusDaypartVisualStyle {
    let cardFill: Color
    let cardBorder: Color
    let primaryForeground: Color
    let secondaryForeground: Color
    let accentFill: Color
    let accentForeground: Color
}

struct FocusDaypartBackground: View {
    let daypart: FocusDaypart

    var body: some View {
        let palette = daypart.palette

        ZStack {
            LinearGradient(
                colors: [palette.base, palette.depth],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [palette.highlight.opacity(0.82), .clear],
                center: UnitPoint(x: 0.84, y: 0.16),
                startRadius: 8,
                endRadius: 430
            )

            RadialGradient(
                colors: [palette.depth.opacity(0.72), .clear],
                center: UnitPoint(x: 0.06, y: 0.92),
                startRadius: 12,
                endRadius: 520
            )
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct FocusDaypartPalette {
    let base: Color
    let highlight: Color
    let depth: Color
}

private struct FocusDaypartPreviewKey: EnvironmentKey {
    static let defaultValue: FocusDaypart? = nil
}

extension EnvironmentValues {
    var focusDaypartPreviewOverride: FocusDaypart? {
        get { self[FocusDaypartPreviewKey.self] }
        set { self[FocusDaypartPreviewKey.self] = newValue }
    }
}

#Preview("Focus background - morning") {
    FocusDaypartBackground(daypart: .morning)
}

#Preview("Focus background - afternoon") {
    FocusDaypartBackground(daypart: .afternoon)
}

#Preview("Focus background - night") {
    FocusDaypartBackground(daypart: .night)
}
