import SwiftUI
import UIKit

struct TyfeCircleInviteCardView: View {
    let code: String

    @State private var didCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    Text("Invite code")
                        .font(TyfeTypography.eyebrow)
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    Text(code)
                        .font(TyfeTypography.timer)
                        .textSelection(.enabled)
                        .accessibilityLabel(Text("Invite code \(code)"))

                    Text("Single use. Expires in 7 days.")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }
            }

            TyfeActionButtonView(
                title: didCopy ? "Copied" : "Copy code",
                systemImage: didCopy ? "checkmark" : "doc.on.doc",
                role: .secondary,
                onTap: { copyCode() }
            )
        }
    }

    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation { didCopy = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { didCopy = false }
        }
    }
}
