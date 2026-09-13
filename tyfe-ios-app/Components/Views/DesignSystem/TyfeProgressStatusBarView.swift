import SwiftUI
import SwiftfulUI

struct TyfeProgressStatusBarView: View {

    var title: String
    var timeText: String
    var systemImage: String
    var accent: Color
    var accessibilityHint: String
    var accessibilityIdentifier: String
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
        .background(accent)
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
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Progress status bars") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeProgressStatusBarView(
            title: "Reward in progress",
            timeText: "12:30",
            systemImage: "clock.fill",
            accent: TyfeEditorialPalette.saffron,
            accessibilityHint: "Opens Rewards",
            accessibilityIdentifier: "reward-in-progress-status"
        )

        TyfeProgressStatusBarView(
            title: "Focus in progress",
            timeText: "18:42",
            systemImage: "timer",
            accent: TyfeEditorialPalette.focus,
            accessibilityHint: "Opens Focus",
            accessibilityIdentifier: "focus-in-progress-status"
        )
    }
        .padding(TyfeSpacing.card)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(TyfeEditorialPalette.canvas)
}
