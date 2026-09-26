import SwiftUI

struct TyfeTierLegendView: View {

    let minContentHeight: CGFloat?

    init(minContentHeight: CGFloat? = nil) {
        self.minContentHeight = minContentHeight
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Text("REWARD RATE")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.1)
                    .foregroundStyle(TyfeEditorialPalette.muted)

                HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                    rateValue("1", unit: "CREDIT")

                    Text("=")
                        .font(TyfeTypography.interfaceStrong)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    rateValue("10", unit: "MIN")
                }
            }
            .frame(minHeight: minContentHeight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reward rate. 1 credit equals 10 minutes of downtime.")
    }

    private func rateValue(_ value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.unit) {
            Text(value)
                .font(TyfeTypography.displayCompact)

            Text(unit)
                .font(TyfeTypography.eyebrow)
                .tracking(0.8)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Reward rate") {
    TyfeTierLegendView()
        .padding(TyfeSpacing.card)
        .background(TyfeEditorialPalette.canvas)
}
