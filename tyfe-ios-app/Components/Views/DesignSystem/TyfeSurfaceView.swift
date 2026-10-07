import SwiftUI

struct TyfeSurfaceView<Content: View>: View {
    let role: TyfeSurfaceRole
    private let glass: Bool
    private let fillOverride: Color?
    private let foregroundOverride: Color?
    private let strokeColorOverride: Color?
    private let contentPadding: CGFloat
    private let content: Content

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var resolvedFill: Color {
        fillOverride ?? role.fill
    }

    private var resolvedForeground: Color {
        foregroundOverride ?? role.foreground
    }

    private var resolvedStrokeColor: Color {
        if let strokeColorOverride {
            return strokeColorOverride
        }

        switch role {
        case .disabled: return TyfeEditorialPalette.disabledInk
        default: return TyfeEditorialPalette.border
        }
    }

    init(
        role: TyfeSurfaceRole = .paper,
        glass: Bool = false,
        fill: Color? = nil,
        foreground: Color? = nil,
        strokeColor: Color? = nil,
        contentPadding: CGFloat = TyfeSpacing.cardInset,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.glass = glass
        self.fillOverride = fill
        self.foregroundOverride = foreground
        self.strokeColorOverride = strokeColor
        self.contentPadding = contentPadding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(contentPadding)
            .foregroundStyle(resolvedForeground)
            .background {
                if glass && !reduceTransparency {
                    RoundedRectangle(cornerRadius: TyfeRadius.card)
                        .fill(.ultraThinMaterial)
                        .overlay(resolvedFill.opacity(0.24))
                } else {
                    resolvedFill
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.card)
                    .stroke(
                        resolvedStrokeColor,
                        lineWidth: TyfeStroke.standard
                    )
            }
            .shadow(
                color: TyfeEditorialPalette.shadow.opacity(TyfeShadow.opacity),
                radius: TyfeShadow.radius,
                x: TyfeShadow.offset.width,
                y: TyfeShadow.offset.height
            )
    }
}

#Preview("Surface roles") {
    VStack(spacing: TyfeSpacing.itemGap) {
        TyfeSurfaceView(role: .warmCanvas) {
            Text("Warm Canvas")
                .font(TyfeTypography.interfaceStrong)
        }
        TyfeSurfaceView(role: .focusChamber) {
            Text("Focus Chamber")
                .font(TyfeTypography.interfaceStrong)
        }
        TyfeSurfaceView(role: .paper, contentPadding: TyfeSpacing.compactCardInset) {
            Text("Compact padding")
                .font(TyfeTypography.interfaceStrong)
        }
    }
    .padding(TyfeSpacing.cardInset)
    .background(TyfeEditorialPalette.canvas)
}
