import SwiftUI

@Observable
@MainActor
final class TodayPresenter {

    private let interactor: TodayInteractor
    private let router: TodayRouter

    private(set) var activities: [ActivityModel] = []
    private(set) var dailyPlan: DailyPlanModel?
    private(set) var planItems: [DailyPlanItemModel] = []
    private(set) var completedSessionCount = 0
    private(set) var completedSessionCounts: [String: Int] = [:]
    private(set) var rewardCredits = 0
    private(set) var activeFocusSession: FocusSessionModel?

    var selectedPlanItemId: String?
    var isAddActivitySheetPresented = false
    private(set) var addActivitySessionCount = 1

    init(interactor: TodayInteractor, router: TodayRouter) {
        self.interactor = interactor
        self.router = router
    }

    var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    var hasPlan: Bool {
        !planItems.isEmpty
    }

    var hasUnfinishedPlan: Bool {
        planItems.contains { remainingSessionCount(for: $0) > 0 }
    }

    var hasActiveFocusSession: Bool {
        activeFocusSession != nil
    }

    var nextPlanItem: DailyPlanItemModel? {
        planItems.first { remainingSessionCount(for: $0) > 0 }
    }

    var nextActivity: ActivityModel? {
        guard let nextPlanItem else { return nil }
        return activity(for: nextPlanItem)
    }

    var planProgressLabel: String {
        guard let dailyPlan else { return "No plan yet" }
        return "\(completedSessionCount) of \(dailyPlan.intendedSessionCount)"
    }

    func activity(for item: DailyPlanItemModel) -> ActivityModel? {
        activities.first { $0.activityId == item.activityId }
    }

    func completedCount(for item: DailyPlanItemModel) -> Int {
        completedSessionCounts[item.activityId, default: 0]
    }

    func remainingSessionCount(for item: DailyPlanItemModel) -> Int {
        max(item.plannedSessionCount - completedCount(for: item), 0)
    }

    func canDecrement(_ item: DailyPlanItemModel) -> Bool {
        item.plannedSessionCount > completedCount(for: item)
    }

    func onViewAppear(delegate: TodayDelegate) {
        reload()
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: TodayDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onCreatePlanPressed() {
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.createPlan)
    }

    func onAddActivityPressed() {
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.addActivity)
    }

    func onEditPlanPressed() {
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.editPlan)
    }

    func saveActivity(
        name: String,
        category: ActivityCategory,
        sessionCount: Int
    ) {
        guard let activity = interactor.createPhase1Activity(
            name: name,
            category: category,
            colorToken: "teal"
        ) else { return }
        _ = interactor.addPhase1ActivityToDailyPlan(
            activityId: activity.activityId,
            sessionCount: max(sessionCount, 1)
        )
        isAddActivitySheetPresented = false
        reload()
    }

    func increment(_ item: DailyPlanItemModel) {
        _ = interactor.updatePhase1DailyPlanItemCount(
            activityId: item.activityId,
            sessionCount: item.plannedSessionCount + 1
        )
        reload()
    }

    func decrement(_ item: DailyPlanItemModel) {
        guard canDecrement(item) else { return }
        _ = interactor.updatePhase1DailyPlanItemCount(
            activityId: item.activityId,
            sessionCount: item.plannedSessionCount - 1
        )
        reload()
    }

    func remove(_ item: DailyPlanItemModel) {
        guard completedCount(for: item) == 0 else { return }
        _ = interactor.removePhase1ActivityFromDailyPlan(activityId: item.activityId)
        reload()
    }

    func onStartFocusPressed() {
        guard let nextPlanItem else { return }
        onStartFocusPressed(for: nextPlanItem)
    }

    func selectNextPlanItem() {
        moveSelection(by: 1)
    }

    func selectPreviousPlanItem() {
        moveSelection(by: -1)
    }

    func onStartFocusPressed(for item: DailyPlanItemModel) {
        if let activeFocusSession,
           let activity = activities.first(where: { $0.activityId == activeFocusSession.activityId }) {
            selectedPlanItemId = item.id
            interactor.trackEvent(event: Event.startFocus)
            router.showFocusView(delegate: FocusDelegate(activity: activity, session: activeFocusSession))
            return
        }

        guard remainingSessionCount(for: item) > 0,
              let activity = activity(for: item),
              let session = interactor.startPhase1FocusSession(activityId: activity.activityId) else {
            return
        }
        selectedPlanItemId = item.id
        interactor.trackEvent(event: Event.startFocus)
        router.showFocusView(delegate: FocusDelegate(activity: activity, session: session))
    }

    func onResumeActiveFocusPressed() {
        guard let activeFocusSession,
              let activity = activities.first(where: { $0.activityId == activeFocusSession.activityId }) else {
            return
        }
        interactor.trackEvent(event: Event.startFocus)
        router.showFocusView(delegate: FocusDelegate(activity: activity, session: activeFocusSession))
    }

    func onDevSettingsPressed() {
        #if MOCK || DEV
        router.showDevSettingsView()
        #endif
    }

    private func presentAddActivityFlow(sessionCount: Int) {
        addActivitySessionCount = sessionCount
        isAddActivitySheetPresented = true
    }

    private func reload() {
        activities = interactor.phase1Activities
        dailyPlan = interactor.phase1DailyPlan
        planItems = dailyPlan?.planItems ?? []
        completedSessionCount = interactor.phase1CompletedSessionCount
        completedSessionCounts = interactor.phase1CompletedSessionCounts
        rewardCredits = interactor.phase1RewardCredits
        activeFocusSession = interactor.activeFocusSession

        if let selectedPlanItemId,
           planItems.contains(where: { $0.id == selectedPlanItemId }) {
            return
        }
        selectedPlanItemId = planItems.first(where: { remainingSessionCount(for: $0) > 0 })?.id
            ?? planItems.first?.id
    }

    private func moveSelection(by offset: Int) {
        guard !planItems.isEmpty else { return }

        guard let selectedPlanItemId,
              let currentIndex = planItems.firstIndex(where: { $0.id == selectedPlanItemId }) else {
            self.selectedPlanItemId = nextPlanItem?.id ?? planItems.first?.id
            return
        }

        let nextIndex = (currentIndex + offset + planItems.count) % planItems.count
        self.selectedPlanItemId = planItems[nextIndex].id
    }
}

extension TodayPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TodayDelegate)
        case onDisappear(delegate: TodayDelegate)
        case createPlan
        case addActivity
        case editPlan
        case startFocus

        var eventName: String {
            switch self {
            case .onAppear: return "TodayView_Appear"
            case .onDisappear: return "TodayView_Disappear"
            case .createPlan: return "Today_CreatePlan"
            case .addActivity: return "Today_AddActivity"
            case .editPlan: return "Today_EditPlan"
            case .startFocus: return "Today_StartFocus"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createPlan, .addActivity, .editPlan, .startFocus:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
