import SwiftUI

@Observable
@MainActor
final class DailyPlanPresenter {

    private let interactor: DailyPlanInteractor
    private let router: DailyPlanRouter

    let activity: ActivityModel
    let existingPlan: DailyPlanModel?
    private let onComplete: (() -> Void)?

    var intendedSessionCount: Int

    init(
        interactor: DailyPlanInteractor,
        router: DailyPlanRouter,
        delegate: DailyPlanDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.activity = delegate.activity
        self.existingPlan = delegate.existingPlan
        self.onComplete = delegate.onComplete
        self.intendedSessionCount = max(delegate.existingPlan?.intendedSessionCount ?? 3, 1)
    }

    var canDecrement: Bool {
        intendedSessionCount > 1
    }

    var planSummary: String {
        let noun = intendedSessionCount == 1 ? "session" : "sessions"
        return String(intendedSessionCount) + " " + noun + " planned"
    }

    func onViewAppear(delegate: DailyPlanDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: DailyPlanDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func decrementSessionCount() {
        guard canDecrement else { return }
        intendedSessionCount -= 1
    }

    func incrementSessionCount() {
        guard intendedSessionCount < 8 else { return }
        intendedSessionCount += 1
    }

    func acceptPlan() {
        _ = interactor.acceptPhase1DailyPlan(
            intendedSessionCount: intendedSessionCount,
            activityIds: [activity.activityId],
            timeBlocks: nil
        )
        interactor.trackEvent(event: Event.planAccepted)

        if let onComplete {
            onComplete()
        } else {
            router.dismissPushStack()
        }
    }

    func onBackPressed() {
        router.dismissScreen()
    }

}

extension DailyPlanPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: DailyPlanDelegate)
        case onDisappear(delegate: DailyPlanDelegate)
        case planAccepted

        var eventName: String {
            switch self {
            case .onAppear: return "DailyPlanView_Appear"
            case .onDisappear: return "DailyPlanView_Disappear"
            case .planAccepted: return "DailyPlan_Accepted"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .planAccepted:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
