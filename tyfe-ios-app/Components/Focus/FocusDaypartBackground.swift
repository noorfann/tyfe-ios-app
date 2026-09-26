import SwiftUI

enum FocusDaypart: CaseIterable, Hashable, Sendable {
    case morning
    case midday
    case afternoon
    case night

    init(date: Date, calendar: Calendar = .autoupdatingCurrent) {
        switch calendar.component(.hour, from: date) {
        case 6..<12:
            self = .morning
        case 12..<15:
            self = .midday
        case 15..<18:
            self = .afternoon
        default:
            self = .night
        }
    }

    var symbolName: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .midday, .afternoon: return "cloud.sun.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var greeting: String {
        switch self {
        case .morning: return "Good Morning"
        case .midday, .afternoon: return "Good Afternoon"
        case .night: return "Good Evening"
        }
    }

    var foreground: Color {
        visualStyle.primaryForeground
    }

    var symbolColor: Color {
        visualStyle.accentFill
    }

    var usesVerticalWhiteFade: Bool {
        self == .morning || self == .midday
    }

    var visualStyle: FocusDaypartVisualStyle {
        switch self {
        case .morning, .midday:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "173F62"),
                cardBorder: Color(hex: "72B7D9"),
                primaryForeground: Color(hex: "F7F7F2"),
                secondaryForeground: Color(hex: "C7D9E5"),
                accentFill: Color(hex: "FFE49A"),
                focusAccentFill: Color(hex: "72B7D9"),
                accentForeground: Color(hex: "1E201C"),
                backgroundForeground: Color(hex: "1E201C")
            )
        case .afternoon:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "4D3A4D"),
                cardBorder: Color(hex: "C99B83"),
                primaryForeground: Color(hex: "FFF0D8"),
                secondaryForeground: Color(hex: "E9C8BE"),
                accentFill: Color(hex: "F4C98B"),
                focusAccentFill: Color(hex: "F4C98B"),
                accentForeground: Color(hex: "443342"),
                backgroundForeground: Color(hex: "3E2B35")
            )
        case .night:
            FocusDaypartVisualStyle(
                cardFill: Color(hex: "111A36"),
                cardBorder: Color(hex: "6F86B6"),
                primaryForeground: Color(hex: "F7F7F2"),
                secondaryForeground: Color(hex: "C8D1E8"),
                accentFill: Color(hex: "DCE7FF"),
                focusAccentFill: Color(hex: "DCE7FF"),
                accentForeground: Color(hex: "1E201C"),
                backgroundForeground: Color(hex: "F7F7F2")
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

    var palette: FocusDaypartPalette {
        switch self {
        case .morning, .midday:
            FocusDaypartPalette(
                base: Color(hex: "5EA9D0"),
                highlight: Color(hex: "A8DDF0"),
                depth: Color(hex: "62A8C8"),
                horizon: Color(hex: "72B7D9")
            )
        case .afternoon:
            FocusDaypartPalette(
                base: Color(hex: "B7AAA1"),
                highlight: Color(hex: "FF981F"),
                depth: Color(hex: "292239"),
                horizon: Color(hex: "D84432")
            )
        case .night:
            FocusDaypartPalette(
                base: Color(hex: "292239"),
                highlight: Color(hex: "8491C2"),
                depth: Color(hex: "0B1026"),
                horizon: Color(hex: "3A416D")
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
    let focusAccentFill: Color
    let accentForeground: Color
    let backgroundForeground: Color
}

struct FocusDaypartBackground: View {
    let daypart: FocusDaypart

    var body: some View {
        let palette = daypart.palette
        let highlightCenter = daypart == .afternoon
            ? UnitPoint(x: 0.82, y: 0.58)
            : UnitPoint(x: 0.84, y: 0.16)

        if daypart.usesVerticalWhiteFade {
            LinearGradient(
                colors: [palette.base, .white],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
        } else {
            ZStack {
                if daypart == .afternoon {
                    LinearGradient(
                        stops: [
                            .init(color: palette.base, location: 0),
                            .init(color: palette.highlight, location: 0.46),
                            .init(color: palette.horizon, location: 0.76),
                            .init(color: palette.depth, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else if daypart == .night {
                    LinearGradient(
                        stops: [
                            .init(color: palette.base, location: 0),
                            .init(color: palette.horizon, location: 0.42),
                            .init(color: Color(hex: "192343"), location: 0.72),
                            .init(color: palette.depth, location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    LinearGradient(
                        colors: [palette.base, palette.depth],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

                RadialGradient(
                    colors: [palette.highlight.opacity(0.82), .clear],
                    center: highlightCenter,
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
}

struct FocusDaypartPalette {
    let base: Color
    let highlight: Color
    let depth: Color
    let horizon: Color
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

#Preview("Focus background - midday") {
    FocusDaypartBackground(daypart: .midday)
}

#Preview("Focus background - afternoon") {
    FocusDaypartBackground(daypart: .afternoon)
}

#Preview("Focus background - night") {
    FocusDaypartBackground(daypart: .night)
}
