import SwiftUI

struct TyfeFocusTimerView: View {
    let session: FocusSessionModel
    let activityTitle: String
    let timeText: String
    let onBegin: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onAbandon: () -> Void

    private var pauseDescription: String {
        switch session.state {
        case .ready: return "One pause · up to 5 minutes"
        case .running: return session.pauseUsed ? "Pause used" : "One pause · up to 5 minutes"
        case .paused: return "\(max(session.pauseRemainingSeconds / 60, 0)) minutes left in pause allowance"
        case .completed, .abandoned: return "No pause available"
        }
    }

    private var pauseSymbol: String {
        session.pauseUsed ? "pause.circle" : "pause.circle.fill"
    }

    var body: some View {
        TyfeSurfaceView(role: .focusChamber) {
            VStack(alignment: .center, spacing: TyfeSpacing.control) {
                TyfeStateBadgeView(state: session.state)
                Text(activityTitle)
                    .font(TyfeTypography.displayCompact)
                    .multilineTextAlignment(.center)
                Text(timeText)
                    .font(TyfeTypography.timer)
                    .monospacedDigit()
                    .foregroundStyle(TyfeEditorialPalette.focus)
                    .minimumScaleFactor(0.7)
                    .accessibilityLabel(Text("Focus timer"))
                    .accessibilityValue(Text(timeText))
                HStack(spacing: TyfeSpacing.small) {
                    Image(systemName: pauseSymbol)
                    Text(pauseDescription)
                        .font(TyfeTypography.caption)
                }
                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.82))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text("Pause allowance"))
                .accessibilityValue(Text(pauseDescription))
                primaryAction
                if session.state == .ready || session.state == .running || session.state == .paused {
                    TyfeActionButtonView(
                        title: "Abandon session",
                        systemImage: "stop.fill",
                        role: .destructive,
                        onTap: onAbandon
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var primaryAction: some View {
        switch session.state {
        case .ready:
            TyfeActionButtonView(title: "Begin Focus", systemImage: "play.fill", onTap: onBegin)
        case .running:
            TyfeActionButtonView(title: "Pause", systemImage: "pause.fill", isEnabled: !session.pauseUsed, onTap: onPause)
        case .paused:
            TyfeActionButtonView(title: "Resume", systemImage: "play.fill", onTap: onResume)
        case .completed:
            TyfePillView(label: "Session complete", systemImage: "checkmark.circle.fill", tone: .accent)
        case .abandoned:
            TyfePillView(label: "Session ended", systemImage: "stop.circle.fill", tone: .error)
        }
    }
}

#Preview("Focus timer — ready") {
    TyfeFocusTimerView(
        session: .readyMock,
        activityTitle: "Study Swift",
        timeText: "25:00",
        onBegin: {},
        onPause: {},
        onResume: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Focus timer — paused") {
    TyfeFocusTimerView(
        session: .pausedMock,
        activityTitle: "Study Swift",
        timeText: "04:32",
        onBegin: {},
        onPause: {},
        onResume: {},
        onAbandon: {}
    )
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}

#Preview("Focus timer — outcomes") {
    VStack(spacing: TyfeSpacing.control) {
        TyfeFocusTimerView(
            session: .completedMock,
            activityTitle: "Study Swift",
            timeText: "00:00",
            onBegin: {},
            onPause: {},
            onResume: {},
            onAbandon: {}
        )
        TyfeFocusTimerView(
            session: .abandonedMock,
            activityTitle: "Study Swift",
            timeText: "08:11",
            onBegin: {},
            onPause: {},
            onResume: {},
            onAbandon: {}
        )
    }
    .padding(TyfeSpacing.card)
    .background(TyfeEditorialPalette.canvas)
}
