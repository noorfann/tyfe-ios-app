import SwiftUI

@Observable
@MainActor
final class OnboardingPresenter {

    private let interactor: OnboardingInteractor
    private let router: OnboardingRouter

    private(set) var currentIndex: Int = 0

    init(interactor: OnboardingInteractor, router: OnboardingRouter) {
        self.interactor = interactor
        self.router = router
    }

    var pages: [OnboardingPage] {
        OnboardingContent.pages
    }

    var isFirstPage: Bool {
        currentIndex == 0
    }

    var isLastPage: Bool {
        currentIndex == pages.count - 1
    }

    var primaryButtonTitle: String {
        isLastPage ? "Choose your first Activity" : "Continue"
    }

    func onViewAppear(delegate: OnboardingDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: OnboardingDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onPageSelected(index: Int) {
        guard index >= 0, index < pages.count else { return }
        currentIndex = index
        interactor.trackEvent(event: Event.pageViewed(index: index))
    }

    func goNext() {
        guard currentIndex < pages.count - 1 else { return }
        currentIndex += 1
        interactor.trackEvent(event: Event.pageViewed(index: currentIndex))
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        interactor.trackEvent(event: Event.pageViewed(index: currentIndex))
    }

    func onPrimaryPressed() {
        if isLastPage {
            goToStarterActivity()
        } else {
            goNext()
        }
    }

    func onSkipPressed() {
        goToStarterActivity()
    }

    private func goToStarterActivity() {
        interactor.trackEvent(event: Event.flowComplete)
        router.showStarterActivityView(
            delegate: StarterActivityDelegate(
                onComplete: { [weak self] in
                    self?.router.switchToCoreModule()
                }
            )
        )
    }

}

extension OnboardingPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: OnboardingDelegate)
        case onDisappear(delegate: OnboardingDelegate)
        case pageViewed(index: Int)
        case flowComplete

        var eventName: String {
            switch self {
            case .onAppear: return "OnboardingView_Appear"
            case .onDisappear: return "OnboardingView_Disappear"
            case .pageViewed: return "OnboardingView_PageViewed"
            case .flowComplete: return "OnboardingView_FlowComplete"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .pageViewed(index: let index):
                return ["page_index": index]
            case .flowComplete:
                return nil
            }
        }

        var type: LogType {
            .analytic
        }
    }

}
