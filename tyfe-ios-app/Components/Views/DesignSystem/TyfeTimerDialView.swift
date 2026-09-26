import SwiftUI

struct TyfeTimerDialView: View {
    let timeText: String
    let caption: String
    let progress: Double
    let accent: Color
    let primaryForeground: Color
    let secondaryForeground: Color
    let accessibilityLabel: String
    let accessibilityValue: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scaledDiameter: CGFloat = 248

    init(
        timeText: String,
        caption: String,
        progress: Double,
        accent: Color,
        primaryForeground: Color,
        secondaryForeground: Color,
        accessibilityLabel: String,
        accessibilityValue: String
    ) {
        self.timeText = timeText
        self.caption = caption
        self.progress = min(max(progress, 0), 1)
        self.accent = accent
        self.primaryForeground = primaryForeground
        self.secondaryForeground = secondaryForeground
        self.accessibilityLabel = accessibilityLabel
        self.accessibilityValue = accessibilityValue
    }

    private var diameter: CGFloat {
        let upperBound: CGFloat = dynamicTypeSize.isAccessibilitySize ? 232 : 284
        return min(max(scaledDiameter, 212), upperBound)
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(primaryForeground.opacity(0.035))

            Circle()
                .stroke(
                    primaryForeground.opacity(0.12),
                    style: StrokeStyle(lineWidth: 10)
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(progressAnimation, value: progress)

            Circle()
                .stroke(
                    primaryForeground.opacity(0.18),
                    style: StrokeStyle(lineWidth: TyfeStroke.hairline)
                )
                .padding(18)

            VStack(spacing: TyfeSpacing.small) {
                Text(timeText)
                    .font(.system(size: 54, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(primaryForeground)
                    .minimumScaleFactor(0.62)

                Text(caption)
                    .font(TyfeTypography.caption)
                    .tracking(1.1)
                    .foregroundStyle(secondaryForeground)
            }
            .padding(TyfeSpacing.card)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityValue(Text(accessibilityValue))
    }
}

#Preview("Timer dial") {
    TyfeTimerDialView(
        timeText: "18:42",
        caption: "25 MINUTES",
        progress: 0.75,
        accent: FocusDaypart.night.visualStyle.accentFill,
        primaryForeground: FocusDaypart.night.visualStyle.primaryForeground,
        secondaryForeground: FocusDaypart.night.visualStyle.secondaryForeground,
        accessibilityLabel: "Focus Session timer",
        accessibilityValue: "18:42, Focusing"
    )
    .padding(TyfeSpacing.card)
    .background(FocusDaypart.night.visualStyle.cardFill)
    .environment(\.colorScheme, .dark)
}
