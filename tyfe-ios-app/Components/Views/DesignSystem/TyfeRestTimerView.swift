import SwiftUI
import SwiftfulUI

struct TyfeRestTimerView: View {
    let daypart: FocusDaypart
    let timeText: String
    let progress: Double
    let onSkip: () -> Void
    let onBackToToday: () -> Void

    private var style: FocusDaypartVisualStyle {
        daypart.visualStyle
    }

    var body: some View {
        TyfeSurfaceView(
            role: .focusChamber,
            glass: true,
            fill: style.cardFill,
            foreground: style.primaryForeground,
            strokeColor: style.cardBorder
        ) {
            VStack(spacing: TyfeSpacing.card) {
                restHeading
                restDial
                restGuidance
                actions
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Five-minute Focus rest")
    }

    private var restHeading: some View {
        VStack(spacing: TyfeSpacing.small) {
            TyfePillView(label: "Resting", systemImage: "hourglass", tone: .warning)

            Text("Take a 5-minute rest")
                .font(TyfeTypography.displayCompact)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
    }

    private var restDial: some View {
        TyfeTimerDialView(
            timeText: timeText,
            caption: "5 MINUTES",
            progress: progress,
            accent: style.focusAccentFill,
            primaryForeground: style.primaryForeground,
            secondaryForeground: style.secondaryForeground,
            accessibilityLabel: "Rest timer",
            accessibilityValue: timeText
        )
    }

    private var restGuidance: some View {
        Label(
            "Let your mind reset before your next Focus Session.",
            systemImage: "hourglass"
        )
        .font(TyfeTypography.caption)
        .multilineTextAlignment(.center)
        .foregroundStyle(style.secondaryForeground)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Rest guidance"))
        .accessibilityValue(Text("Let your mind reset before your next Focus Session."))
    }

    private var actions: some View {
        VStack(spacing: TyfeSpacing.small) {
            TyfeActionButtonView(
                title: "Skip and start another",
                systemImage: "arrow.clockwise",
                fill: style.focusAccentFill,
                foreground: style.accentForeground,
                borderColor: style.accentForeground,
                onTap: onSkip
            )

            Text("Back to Today")
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(style.primaryForeground)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                .asButton(.press) {
                    onBackToToday()
                }
                .accessibilityLabel("Back to Today")
        }
    }
}

#Preview("Rest timer") {
    TyfeRestTimerView(
        daypart: .afternoon,
        timeText: "04:12",
        progress: 0.84,
        onSkip: {},
        onBackToToday: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
