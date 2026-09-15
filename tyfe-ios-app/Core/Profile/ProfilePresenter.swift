import SwiftUI

@Observable
@MainActor
class ProfilePresenter {
    
    private let interactor: ProfileInteractor
    private let router: ProfileRouter
    
    init(interactor: ProfileInteractor, router: ProfileRouter) {
        self.interactor = interactor
        self.router = router
    }
    
    func onViewAppear(delegate: ProfileDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }
    
    func onViewDisappear(delegate: ProfileDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
    
}

extension ProfilePresenter {
    
    enum Event: LoggableEvent {
        case onAppear(delegate: ProfileDelegate)
        case onDisappear(delegate: ProfileDelegate)

        var eventName: String {
            switch self {
            case .onAppear:                 return "ProfileView_Appear"
            case .onDisappear:              return "ProfileView_Disappear"
            }
        }
        
        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }
        
        var type: LogType { .analytic }
    }

}
