import SwiftUI

@Observable
@MainActor
final class StreakPresenter {

    private let interactor: StreakInteractor
    private let router: StreakRouter

    var currentStreakData: CurrentStreakData {
        interactor.currentStreakData
    }

    init(interactor: StreakInteractor, router: StreakRouter) {
        self.interactor = interactor
        self.router = router
    }

    func onViewAppear(delegate: StreakDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: StreakDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }
}

extension StreakPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: StreakDelegate)
        case onDisappear(delegate: StreakDelegate)

        var eventName: String {
            switch self {
            case .onAppear: return "StreakView_Appear"
            case .onDisappear: return "StreakView_Disappear"
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
