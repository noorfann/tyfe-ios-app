import SwiftUI

enum TyfeSpacing {
    static let unit: CGFloat = 4
    static let small: CGFloat = 8
    static let control: CGFloat = 16
    static let card: CGFloat = 24
    static let section: CGFloat = 32
}

enum TyfeRadius {
    static let control: CGFloat = 16
    static let card: CGFloat = 20
    static let surface: CGFloat = 28
    static let phone: CGFloat = 40
}

enum TyfeStroke {
    static let hairline: CGFloat = 1
    static let standard: CGFloat = 2
    static let emphasis: CGFloat = 3
}

enum TyfeShadow {
    static let offset = CGSize(width: 3, height: 4)
    static let radius: CGFloat = 0
    static let opacity: Double = 0.16
}

enum TyfeTypography {
    static let display = Font.system(.largeTitle, design: .serif, weight: .black)
    static let displayCompact = Font.system(.title2, design: .serif, weight: .black)
    static let interface = Font.system(.body, design: .rounded, weight: .semibold)
    static let interfaceStrong = Font.system(.headline, design: .rounded, weight: .bold)
    static let eyebrow = Font.system(.caption, design: .rounded, weight: .bold)
    static let caption = Font.system(.caption2, design: .rounded, weight: .semibold)
    static let timer = Font.system(.largeTitle, design: .monospaced, weight: .bold).monospacedDigit()
}

enum TyfeMotion {
    static let normalDuration: Double = 0.28
    static let reducedDuration: Double = 0
    static let normalAnimation = Animation.easeInOut(duration: normalDuration)
    static let reducedAnimation: Animation? = nil
}

enum TyfeSurfaceRole: CaseIterable {
    case warmCanvas
    case paper
    case disabled
    case focusChamber
    case celebration
    case warning
    case streakBoard

    var fill: Color {
        switch self {
        case .warmCanvas: return TyfeEditorialPalette.canvas
        case .paper: return TyfeEditorialPalette.paper
        case .disabled: return TyfeEditorialPalette.disabledFill
        case .focusChamber: return TyfeEditorialPalette.charcoal
        case .celebration: return TyfeEditorialPalette.focus
        case .warning: return TyfeEditorialPalette.saffron
        case .streakBoard: return TyfeEditorialPalette.board
        }
    }

    var foreground: Color {
        switch self {
        case .focusChamber: return TyfeEditorialPalette.onDark
        case .disabled: return TyfeEditorialPalette.disabledInk
        case .celebration, .warning: return TyfeEditorialPalette.onAccent
        case .streakBoard: return TyfeEditorialPalette.onBoard
        default: return TyfeEditorialPalette.ink
        }
    }
}

#Preview("Tyfe tokens — Warm Canvas") {
    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
        Text("Tyfe")
            .font(TyfeTypography.display)
        Text("Warm game board")
            .font(TyfeTypography.interfaceStrong)
        HStack(spacing: TyfeSpacing.small) {
            tokenSwatch("Focus", TyfeEditorialPalette.focus)
            tokenSwatch("Cyan", TyfeEditorialPalette.teal)
            tokenSwatch("Error", TyfeEditorialPalette.error)
        }
    }
    .padding(TyfeSpacing.card)
    .foregroundStyle(TyfeEditorialPalette.ink)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Tyfe tokens — Focus Chamber") {
    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
        Text("Focus Chamber")
            .font(TyfeTypography.displayCompact)
        Text("25:00")
            .font(TyfeTypography.timer)
            .foregroundStyle(TyfeEditorialPalette.focus)
        Text("Focusing · Rest after completion")
            .font(TyfeTypography.interface)
            .foregroundStyle(TyfeEditorialPalette.onDark)
    }
    .padding(TyfeSpacing.card)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(TyfeEditorialPalette.navy)
    .foregroundStyle(TyfeEditorialPalette.onDark)
}

private func tokenSwatch(_ label: String, _ color: Color) -> some View {
    Text(label)
        .font(TyfeTypography.caption)
        .padding(.horizontal, TyfeSpacing.small)
        .padding(.vertical, TyfeSpacing.unit)
        .foregroundStyle(TyfeEditorialPalette.onAccent)
        .background(color)
        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
        .overlay {
            RoundedRectangle(cornerRadius: TyfeRadius.control)
                .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.hairline)
        }
}
