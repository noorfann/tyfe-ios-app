import SwiftUI

struct TyfeRewardCardView: View {

    let reward: RewardModel
    let balance: Int
    let onTap: () -> Void

    private var isAvailable: Bool {
        reward.availability == .available
    }

    var body: some View {
        TyfeSurfaceView(role: isAvailable ? .paper : .disabled) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                HStack(spacing: TyfeSpacing.small) {
                    Text(reward.name)
                        .font(TyfeTypography.interfaceStrong)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    TyfePillView(
                        label: availabilityLabel,
                        systemImage: availabilitySymbol,
                        tone: availabilityTone
                    )
                }

                Text(tierLabel)
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                if reward.availability == .insufficientBalance {
                    Text("You need \(costLabel). You have \(balance).")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }

                if isAvailable {
                    TyfeActionButtonView(
                        title: "Take this Reward",
                        systemImage: "gift.fill",
                        onTap: onTap
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(reward.name), \(tierLabel), \(availabilityLabel)"))
    }

    private var tierLabel: String {
        "\(reward.durationTier.durationMinutes) minutes · \(costLabel)"
    }

    private var costLabel: String {
        reward.durationTier.creditCost == 1 ? "1 Credit" : "\(reward.durationTier.creditCost) Credits"
    }

    private var availabilityLabel: String {
        switch reward.availability {
        case .available: return "Available"
        case .insufficientBalance: return "Need more"
        case .unavailable: return "Unavailable"
        }
    }

    private var availabilitySymbol: String {
        switch reward.availability {
        case .available: return "checkmark.circle.fill"
        case .insufficientBalance: return "lock.fill"
        case .unavailable: return "slash.circle.fill"
        }
    }

    private var availabilityTone: TyfePillTone {
        switch reward.availability {
        case .available: return .accent
        case .insufficientBalance: return .warning
        case .unavailable: return .neutral
        }
    }
}

#Preview("Reward cards") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeRewardCardView(reward: RewardModel.starters[0], balance: 2, onTap: {})
        TyfeRewardCardView(reward: RewardModel.starters[2], balance: 2, onTap: {})
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
