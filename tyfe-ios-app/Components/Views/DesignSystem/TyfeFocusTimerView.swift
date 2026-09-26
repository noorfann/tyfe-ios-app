import SwiftUI
import SwiftfulUI

struct TyfeFocusTimerView: View {
    let session: FocusSessionModel
    let daypart: FocusDaypart
    let activityTitle: String
    let timeText: String
    let progress: Double
    let supportingText: String
    let onBegin: () -> Void
    let onAbandon: () -> Void

    init(
        session: FocusSessionModel,
        daypart: FocusDaypart,
        activityTitle: String,
        timeText: String,
        progress: Double = 1,
        supportingText: String? = nil,
        onBegin: @escaping () -> Void,
        onAbandon: @escaping () -> Void
    ) {
        self.session = session
        self.daypart = daypart
        self.activityTitle = activityTitle
        self.timeText = timeText
        self.progress = min(max(progress, 0), 1)
        self.supportingText = supportingText ?? Self.defaultSupportingText(for: session)
        self.onBegin = onBegin
        self.onAbandon = onAbandon
    }

    var body: some View {
        TyfeSurfaceView(
            role: .focusChamber,
            glass: true,
            fill: daypart.visualStyle.cardFill,
            foreground: daypart.visualStyle.primaryForeground,
            strokeColor: daypart.visualStyle.cardBorder
        ) {
            VStack(spacing: TyfeSpacing.card) {
                sessionHeading
                timerDial
                sessionGuidance
                actions
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var sessionHeading: some View {
        Text(activityTitle)
            .font(TyfeTypography.displayCompact)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
    }

    private var timerDial: some View {
        TyfeTimerDialView(
            timeText: timeText,
            caption: timerCaption,
            progress: progress,
            accent: daypart.visualStyle.accentFill,
            primaryForeground: daypart.visualStyle.primaryForeground,
            secondaryForeground: daypart.visualStyle.secondaryForeground,
            accessibilityLabel: "Focus Session timer",
            accessibilityValue: "\(timeText), \(session.state.displayName)"
        )
    }

    private var timerCaption: String {
        "\(session.durationMinutes) MINUTES"
    }

    private var sessionGuidance: some View {
        Label(supportingText, systemImage: session.state == .running ? "timer" : "play.circle.fill")
            .font(TyfeTypography.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(daypart.visualStyle.secondaryForeground)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Focus guidance"))
            .accessibilityValue(Text(supportingText))
    }

    private var actions: some View {
        VStack(spacing: TyfeSpacing.small) {
            primaryAction

            if session.state == .ready || session.state == .running {
                Label("Abandon Session", systemImage: "stop.circle")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.error)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                    .asButton(.press) {
                        onAbandon()
                    }
                    .accessibilityLabel(Text("Abandon Session"))
            }
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch session.state {
        case .ready:
            themedPrimaryButton(title: "Begin Focus", systemImage: "play.fill", onTap: onBegin)
        case .running:
            TyfeFocusStatusPillView(status: .focusing)
        case .completed:
            TyfePillView(label: "Session complete", systemImage: "checkmark.circle.fill", tone: .accent)
        case .abandoned:
            TyfePillView(label: "Session ended", systemImage: "stop.circle.fill", tone: .error)
        }
    }

    private func themedPrimaryButton(
        title: String,
        systemImage: String,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) -> some View {
        TyfeActionButtonView(
            title: title,
            systemImage: systemImage,
            isEnabled: isEnabled,
            fill: daypart.visualStyle.accentFill,
            foreground: daypart.visualStyle.accentForeground,
            borderColor: daypart.visualStyle.accentForeground,
            onTap: onTap
        )
    }

    private static func defaultSupportingText(for session: FocusSessionModel) -> String {
        switch session.state {
        case .ready:
            return "25 minutes of focus"
        case .running:
            return "Phone lock will not stop the timer"
        case .completed:
            return "Focus Session complete"
        case .abandoned:
            return "No Reward Credit earned"
        }
    }

    private static func formatted(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }
}

#Preview("Focus timer - ready") {
    TyfeFocusTimerView(
        session: .readyMock,
        daypart: .morning,
        activityTitle: "Study Swift",
        timeText: "25:00",
        progress: 1,
        onBegin: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Focus timer - running") {
    TyfeFocusTimerView(
        session: .runningMock,
        daypart: .afternoon,
        activityTitle: "Study Swift",
        timeText: "18:42",
        progress: 0.75,
        onBegin: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Focus timer - large type") {
    TyfeFocusTimerView(
        session: .runningMock,
        daypart: .night,
        activityTitle: "Study Swift",
        timeText: "18:42",
        progress: 0.75,
        onBegin: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Focus timer - reduce motion") {
    TyfeFocusTimerView(
        session: .runningMock,
        daypart: .night,
        activityTitle: "Study Swift",
        timeText: "18:42",
        progress: 0.75,
        onBegin: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
    .transaction { transaction in
        transaction.animation = nil
    }
}
