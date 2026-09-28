import SwiftUI

@Observable
@MainActor
final class TodayPresenter {

    private let interactor: TodayInteractor
    private let router: TodayRouter

    private(set) var activities: [ActivityModel] = []
    private(set) var projects: [ProjectModel] = []
    private(set) var dailyPlan: DailyPlanModel?
    private(set) var planItems: [DailyPlanItemModel] = []
    private(set) var completedSessionCount = 0
    private(set) var completedSessionCounts: [String: Int] = [:]
    private(set) var rewardCredits = 0
    private(set) var activeFocusSession: FocusSessionModel?
    private(set) var currentLocalDay: LocalDay
    private(set) var selectedLocalDay: LocalDay
    private(set) var selectedProjectId: String?
    private(set) var earliestRecordedLocalDay: LocalDay?
    var colorScheme: ColorScheme = .light

    var selectedPlanItemId: String?
    var isAddActivitySheetPresented = false
    var isActivityDetailSheetPresented = false
    private(set) var isDeckSwipeCoachmarkPresented = false
    private var pendingDeckCoachmark = false
    private(set) var addActivitySessionCount = 1
    private(set) var editingActivity: ActivityModel?
    private(set) var editingPlanItem: DailyPlanItemModel?
    var addActivityProjectId: String?

    init(interactor: TodayInteractor, router: TodayRouter) {
        self.interactor = interactor
        self.router = router
        let currentLocalDay = interactor.phase1CurrentLocalDay
        self.currentLocalDay = currentLocalDay
        self.selectedLocalDay = currentLocalDay
        self.selectedProjectId = interactor.phase1SelectedProjectId
        self.earliestRecordedLocalDay = interactor.phase1EarliestRecordedLocalDay
        self.colorScheme = interactor.colorScheme
    }

    var isViewingToday: Bool {
        selectedLocalDay == currentLocalDay
    }

    var canViewPreviousDay: Bool {
        guard let earliestRecordedLocalDay else { return false }
        return selectedLocalDay.adding(days: -1).startDate >= earliestRecordedLocalDay.startDate
    }

    var canViewNextDay: Bool {
        selectedLocalDay.startDate < currentLocalDay.startDate
    }

    var selectedDayTitle: String {
        if isViewingToday { return "Today" }
        var format = Date.FormatStyle.dateTime.weekday(.wide)
        format.timeZone = selectedTimeZone
        return selectedLocalDay.startDate.formatted(format)
    }

    var selectedDayDateLabel: String {
        var format = Date.FormatStyle.dateTime.month(.wide).day().year()
        format.timeZone = selectedTimeZone
        return selectedLocalDay.startDate.formatted(format)
    }

    var isDarkAppearance: Bool {
        colorScheme == .dark
    }

    static func streakCount(from data: CurrentStreakData) -> Int {
        data.currentStreak ?? 0
    }

    var currentStreakCount: Int {
        Self.streakCount(from: interactor.currentStreakData)
    }

    func onToggleAppearancePressed() {
        interactor.toggleColorScheme()
        colorScheme = interactor.colorScheme
        interactor.trackEvent(event: Event.toggleAppearance)
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

    var selectedProject: ProjectModel? {
        projects.first { $0.projectId == selectedProjectId }
    }

    var selectedProjectTitle: String {
        selectedProject?.name ?? "Other"
    }

    var deckPlanItems: [DailyPlanItemModel] {
        planItems.filter { activity(for: $0)?.projectId == selectedProjectId }
    }

    var hasUnassignedPlannedActivities: Bool {
        planItems.contains { item in
            guard let activity = activity(for: item) else { return false }
            return activity.projectId == nil
        }
    }

    var hasUnfinishedPlan: Bool {
        planItems.contains { remainingSessionCount(for: $0) > 0 }
    }

    var hasActiveFocusSession: Bool {
        activeFocusSession != nil
    }

    var isRewardInProgress: Bool {
        isViewingToday && interactor.isRewardInProgress
    }

    var nextPlanItem: DailyPlanItemModel? {
        planItems.first { remainingSessionCount(for: $0) > 0 }
    }

    var nextDeckPlanItem: DailyPlanItemModel? {
        deckPlanItems.first { remainingSessionCount(for: $0) > 0 }
    }

    var nextActivity: ActivityModel? {
        guard let nextPlanItem else { return nil }
        return activity(for: nextPlanItem)
    }

    var planProgressLabel: String {
        guard let dailyPlan else { return "No plan yet" }
        let plannedCount = isViewingToday
            ? planItems.reduce(0) { $0 + $1.plannedSessionCount }
            : dailyPlan.intendedSessionCount
        return "\(completedSessionCount) of \(plannedCount)"
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

    func onViewAppear(delegate: TodayDelegate) {
        let latestLocalDay = interactor.phase1CurrentLocalDay
        if selectedLocalDay == currentLocalDay {
            selectedLocalDay = latestLocalDay
        }
        currentLocalDay = latestLocalDay
        reload()
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear(delegate: TodayDelegate) {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onCreatePlanPressed() {
        guard isViewingToday else { return }
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.createPlan)
    }

    func onProjectManagementPressed() {
        guard isViewingToday else { return }
        router.showProjectManagementView(
            delegate: TodayProjectManagementDelegate(onProjectCreated: { [weak self] projectId in
                guard let self else { return }
                reload()
                selectProject(projectId)
            }, onProjectManagementChanged: { [weak self] in
                self?.reload()
            })
        )
        interactor.trackEvent(event: Event.openProjectManagement)
    }

    func selectProject(_ projectId: String?) {
        guard projectId == nil || projects.contains(where: { $0.projectId == projectId }) else { return }
        guard selectedProjectId != projectId else { return }
        selectedProjectId = projectId
        interactor.setPhase1SelectedProjectId(projectId)
        selectFirstDeckItem()
        interactor.trackEvent(event: Event.selectProject)
    }

    func onAddActivityPressed() {
        guard isViewingToday else { return }
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.addActivity)
    }

    func onStreakPressed() {
        interactor.trackEvent(event: Event.openStreak)
        router.showStreakView(delegate: StreakDelegate())
    }

    func onEditPlanPressed() {
        guard isViewingToday else { return }
        presentAddActivityFlow(sessionCount: 1)
        interactor.trackEvent(event: Event.editPlan)
    }

    func saveActivity(
        name: String,
        category: ActivityCategory?,
        sessionCount: Int,
        projectId: String?
    ) {
        guard isViewingToday else { return }
        guard projectId == nil || projects.contains(where: { $0.projectId == projectId }) else { return }
        guard let activity = interactor.createPhase1Activity(
            name: name,
            category: category,
            colorToken: "teal"
        ) else { return }
        guard interactor.assignPhase1Activity(activityId: activity.activityId, to: projectId) else { return }
        _ = interactor.addPhase1ActivityToDailyPlan(
            activityId: activity.activityId,
            sessionCount: max(sessionCount, 1)
        )
        isAddActivitySheetPresented = false
        if selectedProjectId != projectId {
            selectProject(projectId)
        }
        reload()
        if let newItem = planItems.first(where: { $0.activityId == activity.activityId }) {
            selectedPlanItemId = newItem.id
        }
        pendingDeckCoachmark =
            deckPlanItems.count >= 2 && !interactor.hasSeenDeckSwipeCoachmark
    }

    func onAddActivitySheetDismissed() {
        guard pendingDeckCoachmark else { return }
        pendingDeckCoachmark = false
        guard deckPlanItems.count >= 2, !interactor.hasSeenDeckSwipeCoachmark else { return }
        isDeckSwipeCoachmarkPresented = true
        interactor.trackEvent(event: Event.deckSwipeCoachmarkShown)
    }

    func dismissDeckSwipeCoachmark() {
        guard isDeckSwipeCoachmarkPresented else { return }
        isDeckSwipeCoachmarkPresented = false
        interactor.markDeckSwipeCoachmarkSeen()
    }

    func onEditActivityPressed(_ item: DailyPlanItemModel) {
        guard isViewingToday else { return }
        guard let activity = activity(for: item) else { return }
        selectedPlanItemId = item.id
        editingActivity = activity
        editingPlanItem = item
        isActivityDetailSheetPresented = true
        interactor.trackEvent(event: Event.openActivityDetail)
    }

    func saveActivityEdits(
        name: String,
        category: ActivityCategory?,
        sessionCount: Int,
        projectId: String?
    ) {
        guard isViewingToday else { return }
        guard let activity = editingActivity,
              let item = editingPlanItem,
              activity.activityId == item.activityId else { return }
        guard interactor.updatePhase1Activity(
            activityId: activity.activityId,
            name: name,
            category: category
        ) != nil else { return }
        guard interactor.assignPhase1Activity(activityId: activity.activityId, to: projectId) else { return }

        let minimumSessionCount = max(completedCount(for: item), 1)
        _ = interactor.updatePhase1DailyPlanItemCount(
            activityId: item.activityId,
            sessionCount: max(sessionCount, minimumSessionCount)
        )
        dismissActivityDetailSheet()
        if selectedProjectId != projectId {
            selectProject(projectId)
        }
        reload()
        interactor.trackEvent(event: Event.saveActivityDetail)
    }

    func removeEditingActivityFromToday() {
        guard isViewingToday else { return }
        guard let item = editingPlanItem else { return }
        guard completedCount(for: item) == 0 else { return }
        _ = interactor.removePhase1ActivityFromDailyPlan(activityId: item.activityId)
        dismissActivityDetailSheet()
        reload()
        interactor.trackEvent(event: Event.removeActivityFromToday)
    }

    func onActivityDetailSheetDismissed() {
        guard !isActivityDetailSheetPresented else { return }
        editingActivity = nil
        editingPlanItem = nil
    }

    func onStartFocusPressed() {
        guard let selectedPlanItemId,
              let selectedPlanItem = planItems.first(where: { $0.id == selectedPlanItemId }) else {
            return
        }
        onStartFocusPressed(for: selectedPlanItem)
    }

    func selectNextPlanItem() {
        moveSelection(by: 1)
    }

    func selectPreviousPlanItem() {
        moveSelection(by: -1)
    }

    func onStartFocusPressed(for item: DailyPlanItemModel) {
        guard isViewingToday else { return }
        guard !isRewardInProgress else { return }

        selectedPlanItemId = item.id
        guard let activity = activity(for: item) else { return }

        if let activeFocusSession = interactor.activeFocusSession {
            if activeFocusSession.state == .ready,
               activeFocusSession.activityId != activity.activityId {
                guard interactor.abandonPhase1FocusSession(
                    focusSessionId: activeFocusSession.focusSessionId
                ) != nil else {
                    return
                }
            } else if let activeActivity = activities.first(where: {
                $0.activityId == activeFocusSession.activityId
            }) {
                self.activeFocusSession = activeFocusSession
                interactor.trackEvent(event: Event.startFocus)
                router.showFocusView(
                    delegate: FocusDelegate(
                        activity: activeActivity,
                        session: activeFocusSession,
                        onDismiss: focusViewDismissedAction
                    )
                )
                return
            }
        }

        guard remainingSessionCount(for: item) > 0,
              let session = interactor.startPhase1FocusSession(activityId: activity.activityId) else {
            return
        }
        activeFocusSession = session
        interactor.trackEvent(event: Event.startFocus)
        router.showFocusView(
            delegate: FocusDelegate(
                activity: activity,
                session: session,
                onDismiss: focusViewDismissedAction
            )
        )
    }

    func onFocusViewDismissed() {
        reload()
    }

    private var focusViewDismissedAction: () -> Void {
        { [weak self] in
            self?.onFocusViewDismissed()
        }
    }

    func onPreviousDayPressed() {
        guard canViewPreviousDay else { return }
        selectedLocalDay = selectedLocalDay.adding(days: -1)
        isAddActivitySheetPresented = false
        dismissDeckSwipeCoachmark()
        reload()
        interactor.trackEvent(event: Event.viewPreviousDay)
    }

    func onNextDayPressed() {
        guard canViewNextDay else { return }
        let nextDay = selectedLocalDay.adding(days: 1)
        selectedLocalDay = nextDay.startDate > currentLocalDay.startDate ? currentLocalDay : nextDay
        reload()
        interactor.trackEvent(event: Event.viewNextDay)
    }

    func onDevSettingsPressed() {
        #if MOCK || DEV
        router.showDevSettingsView()
        #endif
    }

    private func presentAddActivityFlow(sessionCount: Int) {
        addActivitySessionCount = sessionCount
        addActivityProjectId = selectedProjectId
        isAddActivitySheetPresented = true
    }

    private func dismissActivityDetailSheet() {
        isActivityDetailSheetPresented = false
        editingActivity = nil
        editingPlanItem = nil
    }

    private func reload() {
        interactor.synchronizeRewardCreditDay()
        activities = interactor.phase1Activities
        projects = interactor.phase1Projects.filter { !isViewingToday || !$0.isArchived }
        if let selectedProjectId, !projects.contains(where: { $0.projectId == selectedProjectId }) {
            self.selectedProjectId = nil
            interactor.setPhase1SelectedProjectId(nil)
        } else if selectedProjectId == nil {
            self.selectedProjectId = interactor.phase1SelectedProjectId
        }
        earliestRecordedLocalDay = interactor.phase1EarliestRecordedLocalDay
        dailyPlan = interactor.phase1DailyPlan(for: selectedLocalDay)
        planItems = interactor.phase1VisiblePlanItems(on: selectedLocalDay)
        completedSessionCount = interactor.phase1VisibleCompletedSessionCount(on: selectedLocalDay)
        completedSessionCounts = interactor.phase1CompletedSessionCounts(on: selectedLocalDay)
        rewardCredits = interactor.phase1RewardCredits
        activeFocusSession = interactor.activeFocusSession

        if let selectedPlanItemId,
           deckPlanItems.contains(where: { $0.id == selectedPlanItemId }) {
            return
        }
        selectFirstDeckItem()
    }

    private func moveSelection(by offset: Int) {
        let deckPlanItems = deckPlanItems
        guard !deckPlanItems.isEmpty else { return }

        guard let selectedPlanItemId,
              let currentIndex = deckPlanItems.firstIndex(where: { $0.id == selectedPlanItemId }) else {
            self.selectedPlanItemId = nextDeckPlanItem?.id ?? deckPlanItems.first?.id
            return
        }

        let nextIndex = (currentIndex + offset + deckPlanItems.count) % deckPlanItems.count
        self.selectedPlanItemId = deckPlanItems[nextIndex].id
    }

    private func selectFirstDeckItem() {
        selectedPlanItemId = nextDeckPlanItem?.id ?? deckPlanItems.first?.id
    }

    private var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedLocalDay.timeZoneIdentifier) ?? .current
    }
}

extension TodayPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TodayDelegate)
        case onDisappear(delegate: TodayDelegate)
        case createPlan
        case addActivity
        case editPlan
        case openActivityDetail
        case saveActivityDetail
        case removeActivityFromToday
        case startFocus
        case toggleAppearance
        case openStreak
        case openProjectManagement
        case selectProject
        case deckSwipeCoachmarkShown
        case viewPreviousDay
        case viewNextDay

        var eventName: String {
            switch self {
            case .onAppear: return "TodayView_Appear"
            case .onDisappear: return "TodayView_Disappear"
            case .createPlan: return "Today_CreatePlan"
            case .addActivity: return "Today_AddActivity"
            case .editPlan: return "Today_EditPlan"
            case .openActivityDetail: return "Today_ActivityDetail_Open"
            case .saveActivityDetail: return "Today_ActivityDetail_Save"
            case .removeActivityFromToday: return "Today_Activity_Remove"
            case .startFocus: return "Today_StartFocus"
            case .toggleAppearance: return "Today_ToggleAppearance"
            case .openStreak: return "Today_Streak_Open"
            case .openProjectManagement: return "Today_ProjectManagement_Open"
            case .selectProject: return "Today_Project_Select"
            case .deckSwipeCoachmarkShown: return "Today_DeckSwipeCoachmark_Shown"
            case .viewPreviousDay: return "Today_ViewPreviousDay"
            case .viewNextDay: return "Today_ViewNextDay"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createPlan, .addActivity, .editPlan, .openActivityDetail, .saveActivityDetail,
                    .removeActivityFromToday, .startFocus, .toggleAppearance, .openStreak,
                    .openProjectManagement, .selectProject, .deckSwipeCoachmarkShown,
                    .viewPreviousDay, .viewNextDay:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
