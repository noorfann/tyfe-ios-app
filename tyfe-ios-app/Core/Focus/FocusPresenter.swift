import SwiftUI

@Observable
@MainActor
final class FocusPresenter {

    private let interactor: FocusInteractor
    private let router: FocusRouter

    private(set) var session: FocusSessionModel
    private(set) var remainingFocusSeconds: Int
    private(set) var remainingRestSeconds: Int
    private(set) var completion: FocusCompletionResult?
    private(set) var daypart: FocusDaypart
    private var tickerTask: Task<Void, Never>?
    private var daypartTask: Task<Void, Never>?
    private var isSceneActive = false

    init(interactor: FocusInteractor, router: FocusRouter, session: FocusSessionModel) {
        self.interactor = interactor
        self.router = router
        self.session = session
        self.remainingFocusSeconds = session.durationSeconds
        self.remainingRestSeconds = 0
        self.daypart = FocusDaypart(date: Date())
    }

    var isResting: Bool {
        session.isResting
    }

    var statusTitle: String {
        session.state.displayName
    }

    var timerText: String {
        formatted(seconds: remainingFocusSeconds)
    }

    var restTimerText: String {
        formatted(seconds: remainingRestSeconds)
    }

    var allowanceText: String {
        switch session.state {
        case .ready:
            return "25 minutes of focus"
        case .running:
            return "Phone lock will not stop the timer"
        case .completed:
            return session.restState == .active ? "Rest before your next session" : "Focus Session complete"
        case .abandoned:
            return "Session ended early"
        }
    }

    var primaryActionTitle: String {
        switch session.state {
        case .ready: return "Begin Focus"
        case .running: return "Focus in progress"
        case .completed, .abandoned: return "Session ended"
        }
    }

    var primaryActionSystemImage: String {
        switch session.state {
        case .ready: return "play.fill"
        case .running: return "timer"
        case .completed: return "checkmark.circle.fill"
        case .abandoned: return "stop.circle.fill"
        }
    }

    func onViewAppear(delegate: FocusDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.setFocusScreenVisible(true)
        interactor.prepareSoundEffect(sound: .start, simultaneousPlayers: 1)
        interactor.prepareSoundEffect(sound: .finish, simultaneousPlayers: 1)
        refresh()
        isSceneActive = true
        startTicker()
        startDaypartUpdates()
    }

    func onViewDisappear(delegate: FocusDelegate) {
        isSceneActive = false
        stopTicker()
        stopDaypartUpdates()
        interactor.tearDownSoundEffect(sound: .start)
        interactor.tearDownSoundEffect(sound: .finish)
        interactor.setFocusScreenVisible(false)
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
        delegate.onDismiss?()
    }

    func onPrimaryActionPressed() {
        switch session.state {
        case .ready:
            requestBeginConfirmation()
        case .running, .completed, .abandoned:
            break
        }
    }

    private func requestBeginConfirmation() {
        router.showAlert(
            .alert,
            title: "Start Focus Session?",
            subtitle: "The timer keeps running if you minimize Focus or lock your phone.",
            buttons: {
                AnyView(
                    Group {
                        Button("Start Focus") {
                            self.beginFocusAfterConfirmation()
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    func beginFocusAfterConfirmation() {
        do {
            session = try interactor.beginFocusSession(focusSessionId: session.focusSessionId)
            refresh()
            startTicker()
            interactor.playSoundEffect(sound: .start)
            interactor.trackEvent(event: Event.onBegin)
        } catch FocusManagerError.rewardInProgress {
            showRewardBlockingAlert()
        } catch {
            showPersistenceAlert()
        }
    }

    func onSceneBecameActive() {
        refresh()
        isSceneActive = true
        startDaypartUpdates()
        if session.state == .running || session.isResting {
            startTicker()
        }
    }

    func onSceneBecameInactive() {
        isSceneActive = false
    }

    func onStartAnotherPressed() {
        do {
            if session.state == .completed,
               session.restState == .pending || session.restState == .active {
                session = try interactor.skipFocusRest(focusSessionId: session.focusSessionId)
                interactor.trackEvent(event: Event.onRestSkipped)
            }
            session = try interactor.startAnotherFocusSession(activityId: session.activityId)
            completion = nil
            remainingFocusSeconds = session.durationSeconds
            remainingRestSeconds = 0
            startTicker()
            interactor.trackEvent(event: Event.onStartAnother)
        } catch FocusManagerError.rewardInProgress {
            showRewardBlockingAlert()
        } catch {
            showPersistenceAlert()
        }
    }

    func onStartRestPressed() {
        do {
            session = try interactor.startFocusRest(focusSessionId: session.focusSessionId)
            refresh()
            startTicker()
            interactor.trackEvent(event: Event.onRestStarted)
        } catch {
            showPersistenceAlert()
        }
    }

#if MOCK
    func onMarkCompletePressed() {
        do {
            let wasRunning = session.state == .running
            session = try interactor.markFocusSessionCompleteForTesting(
                focusSessionId: session.focusSessionId
            )
            if wasRunning, session.state == .completed, isSceneActive {
                interactor.playSoundEffect(sound: .finish)
            }
            refresh()
            stopTicker()
        } catch {
            showPersistenceAlert()
        }
    }
#endif

    func onBackToTodayPressed() {
        router.dismissScreen()
    }

    func onMinimizePressed() {
        guard session.state != .running else { return }

        if session.isResting {
            interactor.trackEvent(event: Event.onMinimize)
        }
        router.dismissScreen()
    }

    func onClaimRewardPressed(onNavigateToRewards: () -> Void) {
        interactor.trackEvent(event: Event.onClaimReward)
        router.dismissScreen()
        onNavigateToRewards()
    }

    private func refresh(playCompletionSound: Bool = false) {
        do {
            let previousSession = session
            let refresh = try interactor.refreshFocusSession(focusSessionId: session.focusSessionId)
            session = refresh.session
            remainingFocusSeconds = refresh.remainingFocusSeconds
            remainingRestSeconds = refresh.remainingRestSeconds
            completion = refresh.completion
            if playCompletionSound,
               previousSession.state == .running,
               session.state == .completed {
                interactor.playSoundEffect(sound: .finish)
            }
            if session.state == .completed, session.restState == .active {
                startTicker()
            } else if session.state == .completed || session.state == .abandoned {
                stopTicker()
            }

            if previousSession.restState == .active,
               session.restState == .completed {
                interactor.trackEvent(event: Event.onRestCompleted)
            }
        } catch {
            showPersistenceAlert()
        }
    }

    func onTimerTick() {
        refresh(playCompletionSound: isSceneActive)
    }

    private func startTicker() {
        stopTicker()
        guard session.state == .running || session.isResting else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.onTimerTick()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func startDaypartUpdates() {
        stopDaypartUpdates()
        updateDaypart()
        daypartTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let nextMinute = FocusDaypart.nextMinuteBoundary(after: now)
                let delay = max(nextMinute.timeIntervalSince(now), 0.1)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                self?.updateDaypart()
            }
        }
    }

    private func stopDaypartUpdates() {
        daypartTask?.cancel()
        daypartTask = nil
    }

    private func updateDaypart() {
        daypart = FocusDaypart(date: Date())
    }

    private func showPersistenceAlert() {
        router.showAlert(
            .alert,
            title: "Couldn't save session",
            subtitle: "Your Focus Session is still safe. Please try that action again.",
            buttons: {
                AnyView(
                    Button("OK", role: .cancel) { }
                )
            }
        )
    }

    private func showRewardBlockingAlert() {
        router.showSimpleAlert(
            title: "Reward in progress",
            subtitle: "Finish your Reward before returning to Focus."
        )
    }

    private func formatted(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        return String(format: "%d:%02d", safeSeconds / 60, safeSeconds % 60)
    }

    func onAbandonPressed() {
        interactor.trackEvent(event: Event.onAbandonStart)
        router.showAlert(
            .alert,
            title: "Leave this session?",
            subtitle: "An abandoned Focus Session ends early. You can begin again whenever you’re ready.",
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
        do {
            session = try interactor.abandonFocusSession(focusSessionId: session.focusSessionId)
            completion = nil
            stopTicker()
            interactor.trackEvent(event: Event.onAbandonConfirmed)
        } catch {
            showPersistenceAlert()
        }
    }
}

extension FocusPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: FocusDelegate)
        case onDisappear(delegate: FocusDelegate)
        case onBegin
        case onStartAnother
        case onRestStarted
        case onRestSkipped
        case onRestCompleted
        case onMinimize
        case onAbandonStart
        case onAbandonConfirmed
        case onClaimReward

        var eventName: String {
            switch self {
            case .onAppear:
                return "FocusView_Appear"
            case .onDisappear:
                return "FocusView_Disappear"
            case .onBegin:
                return "FocusView_Begin"
            case .onStartAnother:
                return "FocusView_StartAnother"
            case .onRestStarted:
                return "FocusView_Rest_Started"
            case .onRestSkipped:
                return "FocusView_Rest_Skipped"
            case .onRestCompleted:
                return "FocusView_Rest_Completed"
            case .onMinimize:
                return "FocusView_Minimize"
            case .onAbandonStart:
                return "FocusView_Abandon_Start"
            case .onAbandonConfirmed:
                return "FocusView_Abandon_Confirmed"
            case .onClaimReward:
                return "FocusView_ClaimReward"
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
