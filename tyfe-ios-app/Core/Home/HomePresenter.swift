import SwiftUI

@Observable
@MainActor
class HomePresenter {

    private let interactor: HomeInteractor
    private let router: HomeRouter

    private(set) var dashboardState = HomeDashboardState.empty

    var activityTitle: String {
        dashboardState.activeFocusActivity?.name ?? dashboardState.nextActivity?.name ?? "No activity planned"
    }

    var planCompleted: Int {
        dashboardState.completedSessionCount
    }

    var planTotal: Int {
        dashboardState.plannedSessionCount
    }

    var rewardCredits: Int {
        dashboardState.rewardCredits
    }

    var isRewardInProgress: Bool {
        interactor.isRewardInProgress
    }

    var canStartFocus: Bool {
        !isRewardInProgress && (dashboardState.activeFocusActivity != nil || dashboardState.nextActivity != nil)
    }

    var heroEyebrow: String {
        if isRewardInProgress {
            return "REWARD IN PROGRESS"
        }
        if dashboardState.activeFocusSession != nil {
            return "FOCUS IN PROGRESS"
        }
        return canStartFocus ? "TUESDAY · YOUR PLAN" : "NO PLAN YET"
    }

    var heroTitle: String {
        if isRewardInProgress {
            return "Take your\nReward time."
        }
        if dashboardState.activeFocusSession != nil {
            return "Return to\n\(activityTitle)."
        }
        if canStartFocus {
            return "Make room\nfor a good hour."
        }
        return "Create your\nnext focus plan."
    }

    var heroSubtitle: String {
        if isRewardInProgress {
            return "Finish your current Reward before starting Focus."
        }
        if dashboardState.activeFocusSession != nil {
            return "Your current Focus Session is ready to continue."
        }
        if canStartFocus {
            return "Small effort. Real downtime. Ready when you are."
        }
        return "Create a plan in Today to unlock Focus."
    }

    var focusActionTitle: String {
        if isRewardInProgress {
            return "Reward in progress"
        }
        if dashboardState.activeFocusSession != nil {
            return "Resume Focus"
        }
        return canStartFocus ? "Start Focus" : "Focus unavailable"
    }

    var focusActionSystemImage: String {
        if isRewardInProgress {
            return "clock.fill"
        }
        if dashboardState.activeFocusSession != nil {
            return "arrow.clockwise"
        }
        return canStartFocus ? "arrow.right" : "lock.fill"
    }

    var focusActionAccessibilityLabel: String {
        if isRewardInProgress {
            return "Focus unavailable while Reward is in progress"
        }
        if dashboardState.activeFocusSession != nil {
            return "Resume Focus Session"
        }
        return canStartFocus ? "Start Focus for \(activityTitle)" : "Focus unavailable"
    }

    var focusActionAccessibilityHint: String {
        if isRewardInProgress {
            return "Finish your current Reward before starting a Focus Session."
        }
        if dashboardState.activeFocusSession != nil {
            return "Returns to the Focus Session for \(activityTitle)."
        }
        return canStartFocus
            ? "Begins a 25-minute Focus Session for \(activityTitle)."
            : "Create a plan in Today to start a Focus Session."
    }
    
    init(interactor: HomeInteractor, router: HomeRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: HomeDelegate) {
        reload()
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: HomeDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
    func onDevSettingsPressed() {
        #if MOCK || DEV
        interactor.trackEvent(event: Event.onDevSettings)
        router.showDevSettingsView()
        #else
        interactor.trackEvent(event: Event.onDevSettingsFail)
        #endif
    }

    func onStartFocusPressed() {
        guard !isRewardInProgress else { return }

        guard let session = interactor.startFocusFromHome() else {
            reload()
            return
        }

        reload()
        guard let activity = dashboardState.activeFocusActivity else { return }
        interactor.trackEvent(event: Event.onStartFocus)
        router.showFocusView(delegate: FocusDelegate(activity: activity, session: session))
    }

    private func reload() {
        dashboardState = interactor.dashboardState
    }
}

extension HomePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: HomeDelegate)
        case onDisappear(delegate: HomeDelegate)
        case onDevSettings
        case onDevSettingsFail
        case onStartFocus

        var eventName: String {
            switch self {
            case .onAppear:                 return "HomeView_Appear"
            case .onDisappear:              return "HomeView_Disappear"
            case .onDevSettings:            return "HomeView_DevSettings"
            case .onDevSettingsFail:        return "HomeView_DevSettings_Fail"
            case .onStartFocus:             return "HomeView_StartFocus"
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
            switch self {
            case .onDevSettingsFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
