import SwiftUI
import SwiftfulUI

struct TyfeRewardStatusBarView: View {

    var title: String
    var timeText: String
    var systemImage: String
    var onTap: () -> Void = { }

    var body: some View {
        HStack(spacing: TyfeSpacing.small) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.black))
                .accessibilityHidden(true)

            Text(title)
                .font(TyfeTypography.caption)
                .lineLimit(1)

            Text(timeText)
                .font(TyfeTypography.interfaceStrong)
                .monospacedDigit()
        }
        .foregroundStyle(TyfeEditorialPalette.onAccent)
        .padding(.horizontal, TyfeSpacing.control)
        .frame(minHeight: 40)
        .background(TyfeEditorialPalette.saffron)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
        }
        .shadow(
            color: TyfeEditorialPalette.shadow.opacity(TyfeShadow.opacity),
            radius: TyfeShadow.radius,
            x: TyfeShadow.offset.width,
            y: TyfeShadow.offset.height
        )
        .asButton(.press) {
            onTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(title), \(timeText) remaining"))
        .accessibilityHint("Opens Rewards")
        .accessibilityIdentifier("reward-in-progress-status")
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Reward status bar") {
    TyfeRewardStatusBarView(
        title: "Reward in progress",
        timeText: "12:30",
        systemImage: "clock.fill",
        onTap: { }
    )
        .padding(TyfeSpacing.card)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TyfeEditorialPalette.canvas)
}
