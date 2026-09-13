import SwiftUI

struct TyfeCircleInviteCardView: View {
    let code: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: TyfeSpacing.control) {
            Text("Invite code")
                .font(TyfeTypography.displayCompact)

            Text(code)
                .font(TyfeTypography.timer)
                .textSelection(.enabled)
                .accessibilityLabel(Text("Invite code \(code)"))

            Text("Single use. Expires in 7 days.")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)

            TyfeActionButtonView(title: "Done", role: .primary, onTap: onDone)
        }
        .padding(TyfeSpacing.card)
    }
}
