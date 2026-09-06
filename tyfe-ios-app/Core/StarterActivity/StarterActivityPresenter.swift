import SwiftUI

@Observable
@MainActor
final class StarterActivityPresenter {

    private let interactor: StarterActivityInteractor
    private let router: StarterActivityRouter

    private(set) var activities: [ActivityModel] = []
    var activityName = ActivityModel.mock.name
    var selectedCategory: ActivityCategory = .study
    var selectedColorToken = "teal"

    init(interactor: StarterActivityInteractor, router: StarterActivityRouter) {
        self.interactor = interactor
        self.router = router
    }

    var canContinue: Bool {
        !activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func onViewAppear(delegate: StarterActivityDelegate) {
        activities = interactor.phase1Activities
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: StarterActivityDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func select(activity: ActivityModel) {
        activityName = activity.name
        selectedCategory = activity.category ?? .personal
        selectedColorToken = activity.colorToken ?? "teal"
    }

    func onContinuePressed() {
        guard let activity = interactor.createPhase1Activity(
            name: activityName,
            category: selectedCategory,
            colorToken: selectedColorToken
        ) else {
            return
        }

        interactor.trackEvent(event: Event.activityCreated)
        router.showDailyPlanView(delegate: DailyPlanDelegate(activity: activity))
    }

    func onBackPressed() {
        router.dismissScreen()
    }
}

extension StarterActivityPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: StarterActivityDelegate)
        case onDisappear(delegate: StarterActivityDelegate)
        case activityCreated

        var eventName: String {
            switch self {
            case .onAppear: return "StarterActivityView_Appear"
            case .onDisappear: return "StarterActivityView_Disappear"
            case .activityCreated: return "StarterActivity_Continue"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .activityCreated:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
