import SwiftUI

struct TyfeClaimCardView: View {

    let claim: RewardClaimModel
    let remainingSeconds: Int
    let endText: String
    var startBlockingMessage: String?
    let onStart: () -> Void

    var body: some View {
        switch claim.state {
        case .ready:
            readyCard
        case .active:
            activeCard
        case .expired:
            expiredCard
        }
    }

    private var readyCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Label("Reward ready", systemImage: "gift.fill")
                    .font(TyfeTypography.displayCompact)

                Text("\(claim.durationTier.durationMinutes) minutes · \(costLabel) already spent")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                TyfeActionButtonView(
                    title: "Start now",
                    systemImage: "play.fill",
                    isEnabled: startBlockingMessage == nil,
                    onTap: onStart
                )

                if let startBlockingMessage {
                    Text(startBlockingMessage)
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            startBlockingMessage == nil
                ? "Reward ready"
                : "Reward ready. Start unavailable while Focus is active."
        )
    }

    private var activeCard: some View {
        TyfeSurfaceView(role: .focusChamber) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Label("Reward in progress", systemImage: "clock.fill")
                    .font(TyfeTypography.interfaceStrong)

                Text(remainingText)
                    .font(TyfeTypography.timer)
                    .foregroundStyle(TyfeEditorialPalette.focus)

                Text("Ends at \(endText)")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.7))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reward in progress")
        .accessibilityValue("\(remainingText), ends at \(endText)")
    }

    private var expiredCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Label("Reward finished", systemImage: "checkmark.circle.fill")
                    .font(TyfeTypography.interfaceStrong)

                Text("Unused time does not extend or refund. Claim another Reward when you are ready.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Reward finished")
    }

    private var remainingText: String {
        let safeSeconds = max(remainingSeconds, 0)
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    private var costLabel: String {
        claim.durationTier.creditCost == 1 ? "1 Credit" : "\(claim.durationTier.creditCost) Credits"
    }
}

#Preview("Claim cards") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeClaimCardView(claim: .mock, remainingSeconds: 0, endText: "—", onStart: {})
        TyfeClaimCardView(claim: .activeMock, remainingSeconds: 300, endText: "3:05 PM", onStart: {})
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
