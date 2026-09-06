import SwiftUI

@Observable
@MainActor
final class FocusPresenter {

    private let interactor: FocusInteractor
    private let router: FocusRouter

    private(set) var session: FocusSessionModel

    init(interactor: FocusInteractor, router: FocusRouter, session: FocusSessionModel) {
        self.interactor = interactor
        self.router = router
        self.session = session
    }

    var isPaused: Bool {
        session.state == .paused
    }

    var statusTitle: String {
        session.state.displayName
    }

    var statusDescription: String {
        switch session.state {
        case .ready: return "Ready when you are"
        case .running: return "Stay with this one thing"
        case .paused: return "Take your pause, then return"
        case .completed: return "Session complete"
        case .abandoned: return "Session ended"
        }
    }

    var timerText: String {
        switch session.state {
        case .ready, .running: return "25:00"
        case .paused: return "24:32"
        case .completed: return "00:00"
        case .abandoned: return "24:32"
        }
    }

    var allowanceText: String {
        switch session.state {
        case .ready:
            return "One pause available · up to five minutes"
        case .running:
            return session.pauseUsed ? "Pause used · stay with it" : "One pause available · phone lock will not pause"
        case .paused:
            return "Pause remaining: \(formattedPauseRemaining)"
        case .completed, .abandoned:
            return "No pause available"
        }
    }

    var primaryActionTitle: String {
        switch session.state {
        case .ready: return "Begin Focus"
        case .running: return "Pause once"
        case .paused: return "Resume Focus"
        case .completed, .abandoned: return "Session ended"
        }
    }

    var primaryActionSystemImage: String {
        switch session.state {
        case .ready, .paused: return "play.fill"
        case .running: return "pause.fill"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "stop.circle.fill"
        }
    }

    func onViewAppear(delegate: FocusDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: FocusDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onPrimaryActionPressed() {
        switch session.state {
        case .ready:
            session = updatedSession(state: .running)
            interactor.trackEvent(event: Event.onBegin)
        case .paused:
            session = updatedSession(state: .running)
            interactor.trackEvent(event: Event.onResume)
        case .running:
            guard !session.pauseUsed else { return }
            session = updatedSession(
                state: .paused,
                pausedAt: Date(),
                pauseUsed: true,
                pauseRemainingSeconds: 272
            )
            interactor.trackEvent(event: Event.onPause)
        case .completed, .abandoned:
            break
        }
    }

    func onAbandonPressed() {
        interactor.trackEvent(event: Event.onAbandonStart)
        router.showAlert(
            .alert,
            title: "Leave this session?",
            subtitle: "An abandoned Focus Session earns no Reward Credit and no XP. You can begin again whenever you’re ready.",
            buttons: {
                AnyView(
                    Button("Abandon Session", role: .destructive) {
                        self.onAbandonConfirmed()
                    }
                )
            }
        )
    }

    private func onAbandonConfirmed() {
        interactor.trackEvent(event: Event.onAbandonConfirmed)
        session = updatedSession(state: .abandoned)
        router.dismissScreen()
    }

    private var formattedPauseRemaining: String {
        let minutes = session.pauseRemainingSeconds / 60
        let seconds = session.pauseRemainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func updatedSession(
        state: FocusSessionState,
        pausedAt: Date? = nil,
        pauseUsed: Bool? = nil,
        pauseRemainingSeconds: Int? = nil
    ) -> FocusSessionModel {
        FocusSessionModel(
            focusSessionId: session.focusSessionId,
            activityId: session.activityId,
            state: state,
            startedAt: session.startedAt,
            pausedAt: pausedAt ?? session.pausedAt,
            completedAt: session.completedAt,
            pauseUsed: pauseUsed ?? session.pauseUsed,
            pauseRemainingSeconds: pauseRemainingSeconds ?? session.pauseRemainingSeconds,
            isBonusSession: session.isBonusSession
        )
    }
}

extension FocusPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: FocusDelegate)
        case onDisappear(delegate: FocusDelegate)
        case onBegin
        case onPause
        case onResume
        case onAbandonStart
        case onAbandonConfirmed

        var eventName: String {
            switch self {
            case .onAppear:
                return "FocusView_Appear"
            case .onDisappear:
                return "FocusView_Disappear"
            case .onBegin:
                return "FocusView_Begin"
            case .onPause:
                return "FocusView_Pause"
            case .onResume:
                return "FocusView_Resume"
            case .onAbandonStart:
                return "FocusView_Abandon_Start"
            case .onAbandonConfirmed:
                return "FocusView_Abandon_Confirmed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
