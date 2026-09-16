import SwiftUI
import SwiftfulUI

struct TyfeFocusTimerView: View {
    let session: FocusSessionModel
    let daypart: FocusDaypart
    let activityTitle: String
    let timeText: String
    let progress: Double
    let supportingText: String
    let statusDescription: String
    let onBegin: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onAbandon: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var scaledTimerDiameter: CGFloat = 248

    init(
        session: FocusSessionModel,
        daypart: FocusDaypart,
        activityTitle: String,
        timeText: String,
        progress: Double = 1,
        supportingText: String? = nil,
        statusDescription: String? = nil,
        onBegin: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onResume: @escaping () -> Void,
        onAbandon: @escaping () -> Void
    ) {
        self.session = session
        self.daypart = daypart
        self.activityTitle = activityTitle
        self.timeText = timeText
        self.progress = min(max(progress, 0), 1)
        self.supportingText = supportingText ?? Self.defaultSupportingText(for: session)
        self.statusDescription = statusDescription ?? Self.defaultStatusDescription(for: session.state)
        self.onBegin = onBegin
        self.onPause = onPause
        self.onResume = onResume
        self.onAbandon = onAbandon
    }

    private var timerDiameter: CGFloat {
        let upperBound: CGFloat = dynamicTypeSize.isAccessibilitySize ? 232 : 284
        return min(max(scaledTimerDiameter, 212), upperBound)
    }

    private var timerAccent: Color {
        daypart.visualStyle.accentFill
    }

    private var progressAnimation: Animation? {
        reduceMotion ? nil : .easeOut(duration: 0.12)
    }

    var body: some View {
        TyfeSurfaceView(
            role: .focusChamber,
            fill: daypart.visualStyle.cardFill,
            foreground: daypart.visualStyle.primaryForeground,
            strokeColor: daypart.visualStyle.cardBorder
        ) {
            VStack(spacing: TyfeSpacing.card) {
                sessionHeading
                timerDial
                pauseGuidance
                actions
            }
            .frame(maxWidth: .infinity)
        }
        .environment(\.colorScheme, .dark)
    }

    private var sessionHeading: some View {
        VStack(spacing: TyfeSpacing.small) {
            TyfeStateBadgeView(state: session.state)

            Text(activityTitle)
                .font(TyfeTypography.displayCompact)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            Text(statusDescription)
                .font(TyfeTypography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(daypart.visualStyle.secondaryForeground)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerDial: some View {
        ZStack {
            Circle()
                .fill(daypart.visualStyle.primaryForeground.opacity(0.035))

            Circle()
                .stroke(
                    daypart.visualStyle.primaryForeground.opacity(0.12),
                    style: StrokeStyle(lineWidth: 10)
                )

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    timerAccent,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(progressAnimation, value: progress)

            Circle()
                .stroke(
                    daypart.visualStyle.primaryForeground.opacity(0.18),
                    style: StrokeStyle(lineWidth: TyfeStroke.hairline)
                )
                .padding(18)

            VStack(spacing: TyfeSpacing.small) {
                Text(timeText)
                    .font(.system(size: 54, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(daypart.visualStyle.primaryForeground)
                    .minimumScaleFactor(0.62)

                Text(timerCaption)
                    .font(TyfeTypography.caption)
                    .tracking(1.1)
                    .foregroundStyle(daypart.visualStyle.secondaryForeground)
            }
            .padding(TyfeSpacing.card)
        }
        .frame(width: timerDiameter, height: timerDiameter)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Focus Session timer"))
        .accessibilityValue(Text("\(timeText), \(session.state.displayName)"))
    }

    private var timerCaption: String {
        session.state == .paused
            ? "5-MINUTE PAUSE"
            : "\(session.durationMinutes) MINUTES"
    }

    private var pauseGuidance: some View {
        Label(supportingText, systemImage: pauseSymbol)
            .font(TyfeTypography.caption)
            .multilineTextAlignment(.center)
            .foregroundStyle(daypart.visualStyle.secondaryForeground)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Pause allowance"))
            .accessibilityValue(Text(supportingText))
    }

    private var pauseSymbol: String {
        if session.state == .paused {
            return "hourglass"
        }
        return session.pauseUsed ? "pause.circle" : "pause.circle.fill"
    }

    private var actions: some View {
        VStack(spacing: TyfeSpacing.small) {
            primaryAction

            if session.state == .ready || session.state == .running || session.state == .paused {
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
            themedPrimaryButton(
                title: "Pause once",
                systemImage: "pause.fill",
                isEnabled: !session.pauseUsed,
                onTap: onPause
            )
        case .paused:
            themedPrimaryButton(title: "Resume Focus", systemImage: "play.fill", onTap: onResume)
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
            return "One pause available, up to five minutes"
        case .running:
            return session.pauseUsed ? "Pause used, stay with it" : "One pause available, phone lock will not pause"
        case .paused:
            return "Pause remaining: \(formatted(seconds: session.pauseRemainingSeconds))"
        case .completed, .abandoned:
            return "No pause available"
        }
    }

    private static func defaultStatusDescription(for state: FocusSessionState) -> String {
        switch state {
        case .ready: return "Ready when you are"
        case .running: return "Stay with this one thing"
        case .paused: return "Take your pause, then return"
        case .completed: return "Session complete"
        case .abandoned: return "Session ended"
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
        onPause: {},
        onResume: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Focus timer - paused") {
    TyfeFocusTimerView(
        session: .pausedMock,
        daypart: .afternoon,
        activityTitle: "Study Swift",
        timeText: "04:32",
        progress: 0.91,
        onBegin: {},
        onPause: {},
        onResume: {},
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
        onPause: {},
        onResume: {},
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
        onPause: {},
        onResume: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
    .transaction { transaction in
        transaction.animation = nil
    }
}
