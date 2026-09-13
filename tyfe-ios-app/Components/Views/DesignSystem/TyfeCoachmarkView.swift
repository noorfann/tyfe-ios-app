import SwiftUI
import SwiftfulUI

struct TyfeCoachmarkView: View {

    let title: String
    let message: String
    let systemImage: String
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            HStack(alignment: .top, spacing: TyfeSpacing.small) {
                Image(systemName: systemImage)
                    .font(.headline.weight(.black))
                    .foregroundStyle(TyfeEditorialPalette.onAccent)
                    .frame(width: 40, height: 40)
                    .background(TyfeEditorialPalette.focus)
                    .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))

                VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                    Text(title)
                        .font(TyfeTypography.interfaceStrong)

                    Text(message)
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            swipeHint
        }
        .padding(TyfeSpacing.control)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(TyfeEditorialPalette.onDark)
        .background(TyfeEditorialPalette.charcoal)
        .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.card))
        .overlay {
            RoundedRectangle(cornerRadius: TyfeRadius.card)
                .stroke(TyfeEditorialPalette.onDark, lineWidth: TyfeStroke.standard)
        }
        .shadow(
            color: TyfeEditorialPalette.shadow.opacity(TyfeShadow.opacity),
            radius: TyfeShadow.radius,
            x: TyfeShadow.offset.width,
            y: TyfeShadow.offset.height
        )
        .contentShape(RoundedRectangle(cornerRadius: TyfeRadius.card))
        .asButton(.press, action: onDismiss)
        .accessibilityLabel(Text("\(title). \(message)"))
        .accessibilityHint("Tap to dismiss")
        .accessibilityAddTraits(.isButton)
    }

    private var swipeHint: some View {
        HStack(spacing: TyfeSpacing.small) {
            hintIcon

            Text("Swipe left or right")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.72))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var hintIcon: some View {
        if reduceMotion {
            hintImage
        } else {
            hintImage.symbolEffect(.pulse, options: .repeating)
        }
    }

    private var hintImage: some View {
        Image(systemName: "hand.draw.fill")
            .font(.subheadline.weight(.black))
            .foregroundStyle(TyfeEditorialPalette.onDark)
    }
}

#Preview("Coachmark") {
    TyfeCoachmarkView(
        title: "More activities",
        message: "Your activity cards stack here. Swipe to move between them.",
        systemImage: "rectangle.stack.fill",
        onDismiss: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
