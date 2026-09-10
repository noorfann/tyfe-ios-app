import SwiftUI

@Observable
@MainActor
final class CirclesPresenter {

    private let interactor: CirclesInteractor
    private let router: CirclesRouter

    init(interactor: CirclesInteractor, router: CirclesRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: CirclesDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: CirclesDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension CirclesPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: CirclesDelegate)
        case onDisappear(delegate: CirclesDelegate)

        var eventName: String {
            switch self {
            case .onAppear:    return "CirclesView_Appear"
            case .onDisappear: return "CirclesView_Disappear"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
