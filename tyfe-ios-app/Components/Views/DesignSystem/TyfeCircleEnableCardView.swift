import SwiftUI

struct TyfeCircleEnableCardView: View {
    let onEnable: () -> Void

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Label("Turn on Circles", systemImage: "person.3.fill")
                    .font(TyfeTypography.displayCompact)

                Text("Circles share only today's planned and completed session counts, an available/focusing status, and Cheers. Activities, notes, credits, and rewards stay private.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeActionButtonView(
                    title: "Turn on Circles",
                    systemImage: "checkmark.circle.fill",
                    role: .primary,
                    onTap: onEnable
                )
            }
        }
    }
}
