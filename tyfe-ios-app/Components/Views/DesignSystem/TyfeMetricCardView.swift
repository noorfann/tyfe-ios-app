import SwiftUI

struct TyfeMetricCardView: View {
    let title: String
    let value: String
    let detail: String?
    let systemImage: String
    let accent: Color

    init(
        title: String,
        value: String,
        detail: String? = nil,
        systemImage: String,
        accent: Color
    ) {
        self.title = title
        self.value = value
        self.detail = detail
        self.systemImage = systemImage
        self.accent = accent
    }

    var body: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                HStack(alignment: .center, spacing: TyfeSpacing.small) {
                    RoundedRectangle(cornerRadius: TyfeSpacing.unit)
                        .fill(accent)
                        .frame(width: 12, height: 12)
                        .overlay {
                            RoundedRectangle(cornerRadius: TyfeSpacing.unit)
                                .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
                        }
                    Text(title)
                        .font(TyfeTypography.eyebrow)
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: systemImage)
                        .imageScale(.small)
                }
                HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                    Text(value)
                        .font(TyfeTypography.displayCompact)
                    if let detail {
                        Text(detail)
                            .font(TyfeTypography.caption)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text([value, detail].compactMap { $0 }.joined(separator: " ")))
    }
}

#Preview("Metric cards") {
    HStack(spacing: TyfeSpacing.control) {
        TyfeMetricCardView(
            title: "Credits",
            value: "2",
            detail: "available",
            systemImage: "circle.fill",
            accent: TyfeEditorialPalette.saffron
        )
        TyfeMetricCardView(
            title: "Today",
            value: "1/3",
            detail: "sessions",
            systemImage: "checkmark.circle.fill",
            accent: TyfeEditorialPalette.teal
        )
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
