import SwiftUI

struct TyfeSurfaceView<Content: View>: View {
    let role: TyfeSurfaceRole
    private let content: Content

    init(
        role: TyfeSurfaceRole = .paper,
        @ViewBuilder content: () -> Content
    ) {
        self.role = role
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(TyfeSpacing.card)
            .foregroundStyle(role.foreground)
            .background(role.fill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.card))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.card)
                    .stroke(
                        role == .focusChamber ? TyfeEditorialPalette.onDark : TyfeEditorialPalette.ink,
                        lineWidth: TyfeStroke.standard
                    )
            }
            .shadow(
                color: TyfeEditorialPalette.ink.opacity(TyfeShadow.opacity),
                radius: TyfeShadow.radius,
                x: TyfeShadow.offset.width,
                y: TyfeShadow.offset.height
            )
    }
}

#Preview("Surface roles") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeSurfaceView(role: .warmCanvas) {
            Text("Warm Canvas")
                .font(TyfeTypography.interfaceStrong)
        }
        TyfeSurfaceView(role: .focusChamber) {
            Text("Focus Chamber")
                .font(TyfeTypography.interfaceStrong)
        }
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
