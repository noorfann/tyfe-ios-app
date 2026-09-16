import SwiftUI
import SwiftfulUI

enum TyfeActionButtonRole {
    case primary
    case secondary
    case destructive

    var fill: Color {
        switch self {
        case .primary: return TyfeEditorialPalette.focus
        case .secondary: return TyfeEditorialPalette.paper
        case .destructive: return TyfeEditorialPalette.errorFill
        }
    }

    var foreground: Color {
        switch self {
        case .primary: return TyfeEditorialPalette.onAccent
        case .secondary: return TyfeEditorialPalette.ink
        case .destructive: return TyfeEditorialPalette.onError
        }
    }
}

struct TyfeActionButtonView: View {
    let title: String
    let systemImage: String?
    let role: TyfeActionButtonRole
    let isEnabled: Bool
    private let fillOverride: Color?
    private let foregroundOverride: Color?
    private let borderColorOverride: Color?
    let onTap: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        role: TyfeActionButtonRole = .primary,
        isEnabled: Bool = true,
        fill: Color? = nil,
        foreground: Color? = nil,
        borderColor: Color? = nil,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.fillOverride = fill
        self.foregroundOverride = foreground
        self.borderColorOverride = borderColor
        self.onTap = onTap
    }

    private var resolvedFill: Color {
        isEnabled ? fillOverride ?? role.fill : TyfeEditorialPalette.disabledFill
    }

    private var resolvedForeground: Color {
        isEnabled ? foregroundOverride ?? role.foreground : TyfeEditorialPalette.disabledInk
    }

    private var resolvedBorderColor: Color {
        guard isEnabled else { return TyfeEditorialPalette.controlBorder }
        return borderColorOverride ?? TyfeEditorialPalette.controlBorder
    }

    var body: some View {
        HStack(spacing: TyfeSpacing.small) {
            if let systemImage {
                Image(systemName: systemImage)
                    .imageScale(.medium)
            }
            Text(title)
                .font(TyfeTypography.interfaceStrong)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 44)
        .padding(.horizontal, TyfeSpacing.control)
        .foregroundStyle(resolvedForeground)
        .background(resolvedFill)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(resolvedBorderColor, lineWidth: TyfeStroke.standard)
        }
        .contentShape(Capsule())
        .asButton(.press) {
            guard isEnabled else { return }
            onTap()
        }
        .disabled(!isEnabled)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Action buttons") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeActionButtonView(title: "Start Focus", systemImage: "play.fill") {}
        TyfeActionButtonView(title: "Keep focusing", role: .secondary) {}
        TyfeActionButtonView(title: "Abandon", systemImage: "stop.fill", role: .destructive) {}
        TyfeActionButtonView(title: "Unavailable", role: .primary, isEnabled: false) {}
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
