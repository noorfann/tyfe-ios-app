import SwiftUI

@Observable
@MainActor
final class FocusPresenter {

    private let interactor: FocusInteractor
    private let router: FocusRouter

    private(set) var session: FocusSessionModel
    private(set) var remainingFocusSeconds: Int
    private(set) var remainingPauseSeconds: Int
    private(set) var completion: FocusCompletionResult?
    private(set) var daypart: FocusDaypart
    private var tickerTask: Task<Void, Never>?
    private var daypartTask: Task<Void, Never>?

    init(interactor: FocusInteractor, router: FocusRouter, session: FocusSessionModel) {
        self.interactor = interactor
        self.router = router
        self.session = session
        self.remainingFocusSeconds = session.durationSeconds
        self.remainingPauseSeconds = session.pauseRemainingSeconds
        self.daypart = FocusDaypart(date: Date())
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
        isPaused ? formattedPauseRemaining : formatted(seconds: remainingFocusSeconds)
    }

    var allowanceText: String {
        switch session.state {
        case .ready:
            return "One pause available · up to five minutes"
        case .running:
            return session.pauseUsed ? "Pause used · stay with it" : "One pause available · phone lock will not pause"
        case .paused:
            return "Your Focus timer is held while paused"
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
        interactor.setFocusScreenVisible(true)
        refresh()
        startTicker()
        startDaypartUpdates()
    }

    func onViewDisappear(delegate: FocusDelegate) {
        stopTicker()
        stopDaypartUpdates()
        interactor.setFocusScreenVisible(false)
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onPrimaryActionPressed() {
        do {
            switch session.state {
            case .ready:
                requestBeginConfirmation()
            case .paused:
                session = try interactor.resumeFocusSession(focusSessionId: session.focusSessionId)
                refresh()
                startTicker()
                interactor.trackEvent(event: Event.onResume)
            case .running:
                guard !session.pauseUsed else { return }
                session = try interactor.pauseFocusSession(focusSessionId: session.focusSessionId)
                refresh()
                startTicker()
                interactor.trackEvent(event: Event.onPause)
            case .completed, .abandoned:
                break
            }
        } catch FocusManagerError.rewardInProgress {
            showRewardBlockingAlert()
        } catch {
            showPersistenceAlert()
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

    private func beginFocusAfterConfirmation() {
        do {
            session = try interactor.beginFocusSession(focusSessionId: session.focusSessionId)
            refresh()
            startTicker()
            interactor.trackEvent(event: Event.onBegin)
        } catch FocusManagerError.rewardInProgress {
            showRewardBlockingAlert()
        } catch {
            showPersistenceAlert()
        }
    }

    func onSceneBecameActive() {
        refresh()
        startDaypartUpdates()
        if session.state == .running || session.state == .paused {
            startTicker()
        }
    }

    func onStartAnotherPressed() {
        do {
            session = try interactor.startAnotherFocusSession(activityId: session.activityId)
            completion = nil
            remainingFocusSeconds = session.durationSeconds
            remainingPauseSeconds = session.pauseRemainingSeconds
            startTicker()
        } catch FocusManagerError.rewardInProgress {
            showRewardBlockingAlert()
        } catch {
            showPersistenceAlert()
        }
    }

#if MOCK
    func onMarkCompletePressed() {
        do {
            session = try interactor.markFocusSessionCompleteForTesting(
                focusSessionId: session.focusSessionId
            )
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
        if session.state == .running || session.state == .paused {
            interactor.trackEvent(event: Event.onMinimize)
        }
        router.dismissScreen()
    }

    func onClaimRewardPressed(onNavigateToRewards: () -> Void) {
        interactor.trackEvent(event: Event.onClaimReward)
        router.dismissScreen()
        onNavigateToRewards()
    }

    private func refresh() {
        do {
            let refresh = try interactor.refreshFocusSession(focusSessionId: session.focusSessionId)
            session = refresh.session
            remainingFocusSeconds = refresh.remainingFocusSeconds
            remainingPauseSeconds = refresh.remainingPauseSeconds
            completion = refresh.completion
            if session.state == .completed || session.state == .abandoned {
                stopTicker()
            }
        } catch {
            showPersistenceAlert()
        }
    }

    private func startTicker() {
        stopTicker()
        guard session.state == .running || session.state == .paused else { return }
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refresh()
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

    private var formattedPauseRemaining: String {
        formatted(seconds: remainingPauseSeconds)
    }

    private func updatedSession(
        state: FocusSessionState,
        pausedAt: Date? = nil,
        pauseUsed: Bool? = nil,
        pauseRemainingSeconds: Int? = nil
    ) -> FocusSessionModel {
        session.updated(
            state: state,
            pausedAt: pausedAt,
            pauseUsed: pauseUsed,
            pauseRemainingSeconds: pauseRemainingSeconds
        )
    }

    func onAbandonPressed() {
        interactor.trackEvent(event: Event.onAbandonStart)
        router.showAlert(
            .alert,
            title: "Leave this session?",
            subtitle: "An abandoned Focus Session earns no Reward Credit. You can begin again whenever you’re ready.",
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
        case onPause
        case onResume
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
            case .onPause:
                return "FocusView_Pause"
            case .onResume:
                return "FocusView_Resume"
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
