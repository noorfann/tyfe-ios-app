import SwiftUI

@Observable
@MainActor
final class SplashPresenter {

    private let interactor: SplashInteractor
    private let minimumDisplayDuration: TimeInterval

    private(set) var isFinished: Bool = false

    static let minDisplayDuration: TimeInterval = 0.9

    init(interactor: SplashInteractor, minimumDisplayDuration: TimeInterval = SplashPresenter.minDisplayDuration) {
        self.interactor = interactor
        self.minimumDisplayDuration = minimumDisplayDuration
    }

    func onViewAppear(delegate: SplashDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        finishAfterMinimumDisplay()
    }

    func onViewDisappear(delegate: SplashDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    private func finishAfterMinimumDisplay() {
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(self?.minimumDisplayDuration ?? 0))
            guard let self, !self.isFinished else { return }
            self.isFinished = true
            self.interactor.trackEvent(event: Event.finished)
        }
    }

    enum Event: LoggableEvent {
        case onAppear(delegate: SplashDelegate)
        case onDisappear(delegate: SplashDelegate)
        case finished

        var eventName: String {
            switch self {
            case .onAppear: return "SplashView_Appear"
            case .onDisappear: return "SplashView_Disappear"
            case .finished: return "SplashView_Finished"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .finished:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
