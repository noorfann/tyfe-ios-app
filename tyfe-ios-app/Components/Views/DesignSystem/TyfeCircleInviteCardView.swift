import SwiftUI
import UIKit

struct TyfeCircleInviteCardView: View {
    let code: String
    let onDone: () -> Void

    @State private var didCopy = false

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

            TyfeActionButtonView(
                title: didCopy ? "Copied" : "Copy code",
                systemImage: didCopy ? "checkmark" : "doc.on.doc",
                role: .secondary,
                onTap: { copyCode() }
            )

            TyfeActionButtonView(title: "Done", role: .primary, onTap: onDone)
        }
        .padding(TyfeSpacing.card)
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
