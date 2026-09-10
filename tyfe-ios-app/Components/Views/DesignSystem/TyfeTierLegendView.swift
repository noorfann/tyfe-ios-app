import SwiftUI

struct TyfeTierLegendView: View {

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Text("FIXED DURATION TIERS")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                ForEach(RewardDurationTier.allCases, id: \.self) { tier in
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "clock")
                            .imageScale(.small)
                            .foregroundStyle(TyfeEditorialPalette.terracotta)
                            .accessibilityHidden(true)

                        Text("\(tier.durationMinutes) minutes")
                            .font(TyfeTypography.interface)

                        Spacer(minLength: TyfeSpacing.small)

                        Text(creditLabel(for: tier))
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Fixed duration tiers")
    }

    private func creditLabel(for tier: RewardDurationTier) -> String {
        tier.creditCost == 1 ? "1 Credit" : "\(tier.creditCost) Credits"
    }
}

#Preview("Tier legend") {
    TyfeTierLegendView()
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.canvas)
}
