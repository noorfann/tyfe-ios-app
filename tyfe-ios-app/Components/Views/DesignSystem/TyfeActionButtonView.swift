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
    let onTap: () -> Void

    init(
        title: String,
        systemImage: String? = nil,
        role: TyfeActionButtonRole = .primary,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.role = role
        self.isEnabled = isEnabled
        self.onTap = onTap
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
        .foregroundStyle(isEnabled ? role.foreground : TyfeEditorialPalette.disabledInk)
        .background(isEnabled ? role.fill : TyfeEditorialPalette.disabledFill)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.standard)
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
