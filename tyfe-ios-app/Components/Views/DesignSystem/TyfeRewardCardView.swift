import SwiftUI

struct TyfeRewardCardView: View {

    let reward: RewardModel
    let balance: Int
    var blockingMessage: String?
    let onTap: () -> Void

    @ScaledMetric(relativeTo: .caption2) private var stubWidth: CGFloat = 92

    private var isAvailable: Bool {
        reward.availability == .available && blockingMessage == nil
    }

    private var usesDisabledSurface: Bool {
        blockingMessage != nil || reward.availability == .unavailable
    }

    var body: some View {
        let shape = TyfeCouponShape(tearOffset: stubWidth)

        HStack(spacing: 0) {
            stub
            rewardDetails
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.vertical, TyfeSpacing.card)
        }
        .background(TyfeEditorialPalette.paper)
        .background(alignment: .leading) {
            Rectangle()
                .fill(stubFill)
                .frame(width: stubWidth)
        }
        .overlay(alignment: .topLeading) {
            perforation
        }
        .clipShape(shape)
        .overlay {
            shape.stroke(strokeColor, style: strokeStyle)
        }
        .shadow(
            color: TyfeEditorialPalette.shadow.opacity(TyfeShadow.opacity),
            radius: TyfeShadow.radius,
            x: TyfeShadow.offset.width,
            y: TyfeShadow.offset.height
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            Text(
                "\(reward.name), \(reward.durationTier.creditLabel), "
                    + "\(reward.durationTier.durationMinutes) minutes, \(availabilityLabel)"
            )
        )
    }

    private var stub: some View {
        VStack(spacing: TyfeSpacing.unit) {
            Text(String(reward.durationTier.creditCost))
                .font(TyfeTypography.displayCompact)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(reward.durationTier.creditCost == 1 ? "CREDIT" : "CREDITS")
                .font(TyfeTypography.eyebrow)
                .tracking(0.8)
                .foregroundStyle(stubInk.opacity(0.72))

            Text("\(reward.durationTier.durationMinutes) MIN")
                .font(TyfeTypography.caption)
                .tracking(0.4)
                .foregroundStyle(stubInk.opacity(0.72))
        }
        .foregroundStyle(stubInk)
        .frame(width: stubWidth)
        .padding(.vertical, TyfeSpacing.control)
        .accessibilityHidden(true)
    }

    private var perforation: some View {
        TyfePerforationLine()
            .stroke(style: StrokeStyle(lineWidth: TyfeStroke.hairline, dash: [5, 4]))
            .foregroundStyle(perforationColor)
            .frame(width: TyfeStroke.hairline)
            .padding(.vertical, TyfeSpacing.control)
            .padding(.leading, stubWidth)
            .accessibilityHidden(true)
    }

    private var rewardDetails: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text(reward.name)
                .font(TyfeTypography.interfaceStrong)
                .lineLimit(2, reservesSpace: true)
                .foregroundStyle(detailInk)

            TyfePillView(
                label: availabilityLabel,
                systemImage: availabilitySymbol,
                tone: availabilityTone
            )

            actionSlot
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actionSlot: some View {
        if let blockingMessage {
            slotMessage(blockingMessage)
        } else {
            switch reward.availability {
            case .available:
                TyfeActionButtonView(
                    title: "Claim",
                    systemImage: "gift.fill",
                    onTap: onTap
                )
            case .insufficientBalance:
                slotMessage("You need \(reward.durationTier.creditLabel). You have \(balance).")
            case .unavailable:
                slotMessage("Unavailable right now.")
            }
        }
    }

    private func slotMessage(_ text: String) -> some View {
        Text(text)
            .font(TyfeTypography.caption)
            .foregroundStyle(TyfeEditorialPalette.muted)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
    }

    private var stubFill: Color {
        if isAvailable { return TyfeEditorialPalette.saffron }
        if usesDisabledSurface { return TyfeEditorialPalette.disabledFill }
        return TyfeEditorialPalette.canvas
    }

    private var stubInk: Color {
        if isAvailable { return TyfeEditorialPalette.onAccent }
        if usesDisabledSurface { return TyfeEditorialPalette.disabledInk }
        return TyfeEditorialPalette.ink
    }

    private var detailInk: Color {
        usesDisabledSurface ? TyfeEditorialPalette.disabledInk : TyfeEditorialPalette.ink
    }

    private var perforationColor: Color {
        usesDisabledSurface
            ? TyfeEditorialPalette.disabledInk.opacity(0.6)
            : TyfeEditorialPalette.border.opacity(0.65)
    }

    private var strokeColor: Color {
        usesDisabledSurface ? TyfeEditorialPalette.disabledInk : TyfeEditorialPalette.border
    }

    private var strokeStyle: StrokeStyle {
        if isAvailable {
            return StrokeStyle(lineWidth: TyfeStroke.standard)
        }
        return StrokeStyle(lineWidth: TyfeStroke.standard, dash: [7, 5])
    }

    private var availabilityLabel: String {
        if blockingMessage != nil { return "Focus active" }
        switch reward.availability {
        case .available: return "Available"
        case .insufficientBalance: return "Need more"
        case .unavailable: return "Unavailable"
        }
    }

    private var availabilitySymbol: String {
        if blockingMessage != nil { return "timer" }
        switch reward.availability {
        case .available: return "checkmark.circle.fill"
        case .insufficientBalance: return "lock.fill"
        case .unavailable: return "slash.circle.fill"
        }
    }

    private var availabilityTone: TyfePillTone {
        if blockingMessage != nil { return .neutral }
        switch reward.availability {
        case .available: return .accent
        case .insufficientBalance: return .warning
        case .unavailable: return .neutral
        }
    }
}

#Preview("Reward coupons") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeRewardCardView(reward: RewardModel.starters[0], balance: 2, onTap: {})
        TyfeRewardCardView(reward: RewardModel.starters[1], balance: 2, onTap: {})
        TyfeRewardCardView(
            reward: RewardModel.starters[2],
            balance: 9,
            blockingMessage: "Finish or abandon Focus before claiming a Reward.",
            onTap: {}
        )
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
