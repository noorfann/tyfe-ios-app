import SwiftUI

struct TyfeTierLegendView: View {

    let minContentHeight: CGFloat?

    init(minContentHeight: CGFloat? = nil) {
        self.minContentHeight = minContentHeight
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Text("FIXED DURATION TIERS")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(alignment: .top, spacing: TyfeSpacing.small) {
                    ForEach(RewardDurationTier.allCases, id: \.self) { tier in
                        VStack(spacing: TyfeSpacing.unit) {
                            Image(systemName: "clock")
                                .imageScale(.small)
                                .foregroundStyle(TyfeEditorialPalette.terracotta)
                                .accessibilityHidden(true)

                            Text("\(tier.durationMinutes) MIN")
                                .font(TyfeTypography.eyebrow)
                                .tracking(0.8)
                                .foregroundStyle(TyfeEditorialPalette.muted)
                                .multilineTextAlignment(.center)

                            Text(String(tier.creditCost))
                                .font(TyfeTypography.displayCompact)

                            Text(tier.creditCost == 1 ? "CREDIT" : "CREDITS")
                                .font(TyfeTypography.caption)
                                .foregroundStyle(TyfeEditorialPalette.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(tier.durationMinutes) minutes")
                        .accessibilityValue(creditLabel(for: tier))
                    }
                }
            }
            .frame(minHeight: minContentHeight)
        }
        .accessibilityElement(children: .contain)
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
