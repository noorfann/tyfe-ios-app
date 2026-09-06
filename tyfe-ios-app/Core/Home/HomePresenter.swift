import SwiftUI

@Observable
@MainActor
class HomePresenter {

    private let interactor: HomeInteractor
    private let router: HomeRouter

    private(set) var activityTitle = "Study Swift"
    private(set) var planCompleted = 1
    private(set) var planTotal = 3
    private(set) var rewardCredits = 2
    
    init(interactor: HomeInteractor, router: HomeRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: HomeDelegate) {
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
        interactor.trackEvent(event: Event.onStartFocus)
        router.showFocusView(delegate: FocusDelegate(activityTitle: activityTitle))
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
