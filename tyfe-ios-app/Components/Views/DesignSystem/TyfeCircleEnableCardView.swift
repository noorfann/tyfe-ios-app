import SwiftUI

struct TyfeCircleEnableCardView: View {
    var accountActionTitle = "Create account"
    let onEnable: () -> Void
    var onSignIn: (() -> Void)?

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Label("Unlock Circles", systemImage: "lock.fill")
                    .font(TyfeTypography.displayCompact)

                Text("Create an account or sign in to connect with your Circle. Guest accounts cannot use Circles.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                Text("Circles share only today's planned and completed session counts, an available/focusing status, and Cheers. Activities, notes, credits, and rewards stay private.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeActionButtonView(
                    title: accountActionTitle,
                    systemImage: "person.crop.circle.badge.plus",
                    role: .primary,
                    onTap: onEnable
                )
                .accessibilityIdentifier("circles-create-account")

                if let onSignIn {
                    TyfeActionButtonView(
                        title: "Sign in",
                        systemImage: "arrow.right",
                        role: .secondary,
                        onTap: onSignIn
                    )
                    .accessibilityIdentifier("circles-sign-in")
                }
            }
        }
    }
}
