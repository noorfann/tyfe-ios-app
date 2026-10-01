import SwiftUI
import Testing
@testable import tyfe_ios_app

private struct ProjectHistoryFixture {
    let snapshot: LocalAppSnapshot
    let project: ProjectModel
    let firstActivity: ActivityModel
    let secondActivity: ActivityModel
    let previousDay: LocalDay
    let currentDay: LocalDay
}

@MainActor
struct TodayPresenterTests {

    @Test func streakCountUsesCurrentValueOrZero() {
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: 7)) == 7)
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: 0)) == 0)
        #expect(TodayPresenter.streakCount(from: makeStreakData(currentStreak: nil)) == 0)
    }

    private func makeStreakData(currentStreak: Int?) -> CurrentStreakData {
        CurrentStreakData(
            streakKey: "focus",
            userId: "test-user",
            currentStreak: currentStreak,
            longestStreak: currentStreak,
            totalEvents: currentStreak ?? 0,
            freezesAvailableCount: 0,
            eventsRequiredPerDay: 1,
            todayEventCount: 0
        )
    }

    private func projectHistoryFixture() -> ProjectHistoryFixture {
        let currentDay = LocalDay(containing: Date(), calendar: .autoupdatingCurrent)
        let previousDay = currentDay.adding(days: -1)
        let project = ProjectModel(projectId: "project-writing", name: "Writing")
        let firstActivity = projectActivity(
            id: "activity-project-first",
            name: "Write report",
            category: .work,
            project: project
        )
        let secondActivity = projectActivity(
            id: "activity-project-second",
            name: "Study Swift",
            category: .study,
            project: project
        )
        let plans = [
            projectPlan(id: "daily-plan-project-previous", day: previousDay, activities: [secondActivity]),
            projectPlan(id: "daily-plan-project-current", day: currentDay, activities: [firstActivity, secondActivity])
        ]
        let snapshot = LocalAppSnapshot(
            activities: [firstActivity, secondActivity],
            projects: [project],
            dailyPlans: plans,
            focusSessions: [],
            nextActivityNumber: 1,
            nextProjectNumber: 1,
            nextSessionNumber: 1
        )
        return ProjectHistoryFixture(
            snapshot: snapshot,
            project: project,
            firstActivity: firstActivity,
            secondActivity: secondActivity,
            previousDay: previousDay,
            currentDay: currentDay
        )
    }

    private func projectActivity(
        id: String,
        name: String,
        category: ActivityCategory,
        project: ProjectModel
    ) -> ActivityModel {
        ActivityModel(
            activityId: id,
            name: name,
            category: category,
            projectId: project.projectId,
            createdAt: Date()
        )
    }

    private func projectPlan(
        id: String,
        day: LocalDay,
        activities: [ActivityModel]
    ) -> DailyPlanModel {
        DailyPlanModel(
            dailyPlanId: id,
            localDate: day.startDate,
            localDay: day,
            intendedSessionCount: activities.count,
            originalIntendedSessionCount: activities.count,
            activityIds: activities.map(\.activityId)
        )
    }

    @Test func pressingStreakRequestsDetailRoute() {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)

        presenter.onStreakPressed()

        #expect(router.didShowStreak)
        #expect(TodayPresenter.Event.openStreak.eventName == "Today_Streak_Open")
    }

    @Test func projectManagementOpensDedicatedScreen() {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: router
        )

        presenter.onProjectManagementPressed()

        #expect(router.didShowProjectManagement)
    }

    @Test func streakCountReadsLiveManagerState() async throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let streakManager = try #require(
            dependencies.container.resolve(
                StreakManager.self,
                key: Dependencies.streakConfiguration.streakKey
            )
        )
        try await streakManager.logIn(userId: "today-streak-test-user")
        let interactor = CoreInteractor(container: dependencies.container)
        let presenter = TodayPresenter(interactor: interactor, router: RecordingTodayRouter())

        #expect(presenter.currentStreakCount == 0)
        try await interactor.recordFocusCompletionForStreak(.completedMock)
        #expect(presenter.currentStreakCount == 1)
    }

    @Test func editingActivityUpdatesGlobalDetailsAndPlannedDuration() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let project = try #require(manager.createProject(name: "Writing"))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 2
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)

        presenter.onEditActivityPressed(item)
        #expect(presenter.isActivityDetailSheetPresented)
        #expect(presenter.editingActivity?.activityId == item.activityId)

        presenter.saveActivityEdits(
            ActivitySheetDraft(
                name: "  Renamed activity  ",
                category: .work,
                type: .session,
                checklistItems: [],
                sessionCount: 4,
                projectId: project.projectId,
                recurrence: nil
            )
        )

        #expect(manager.activities.first { $0.activityId == item.activityId }?.name == "Renamed activity")
        #expect(manager.activities.first { $0.activityId == item.activityId }?.category == .work)
        #expect(manager.activities.first { $0.activityId == item.activityId }?.projectId == project.projectId)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 4)
        #expect(!presenter.isActivityDetailSheetPresented)
        #expect(presenter.editingActivity == nil)
        #expect(presenter.editingPlanItem == nil)
    }

    @Test func dismissingActivityEditorDiscardsDraftState() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 2
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)
        let originalActivity = try #require(presenter.activity(for: item))

        presenter.onEditActivityPressed(item)
        presenter.isActivityDetailSheetPresented = false
        presenter.onActivityDetailSheetDismissed()

        #expect(manager.activities.first { $0.activityId == item.activityId } == originalActivity)
        #expect(manager.dailyPlan?.planItems.first?.plannedSessionCount == 2)
        #expect(presenter.editingActivity == nil)
        #expect(presenter.editingPlanItem == nil)
    }

    @Test func removingUnstartedActivityFromEditorClearsPlan() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let item = try #require(presenter.planItems.first)

        presenter.onEditActivityPressed(item)
        presenter.removeEditingActivityFromToday()

        #expect(manager.dailyPlan == nil)
        #expect(!presenter.isActivityDetailSheetPresented)
        #expect(presenter.planItems.isEmpty)
    }

    @Test func creatingActivitySelectsItsCardForImmediateVisibility() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        let existingItem = try #require(presenter.planItems.first)
        #expect(presenter.selectedPlanItemId == existingItem.id)

        presenter.saveActivity(
            ActivitySheetDraft(
                name: "Write report",
                category: .work,
                type: .session,
                checklistItems: [],
                sessionCount: 1,
                projectId: nil,
                recurrence: nil
            )
        )

        let newActivity = try #require(manager.activities.first { $0.name == "Write report" })
        let newItem = try #require(
            presenter.planItems.first { $0.activityId == newActivity.activityId }
        )
        #expect(presenter.planItems.count == 2)
        #expect(presenter.selectedPlanItemId == newItem.id)
    }

    @Test func projectDeckFiltersActivitiesAndKeepsProgressDayWide() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let firstActivity = try #require(manager.activities.first)
        let secondActivity = try #require(manager.createActivity(
            name: "Write report",
            category: .work,
            colorToken: "slateBlue"
        ))
        let writing = try #require(manager.createProject(name: "Writing"))
        let home = try #require(manager.createProject(name: "Home"))
        #expect(manager.assignActivity(activityId: firstActivity.activityId, to: writing.projectId))
        #expect(manager.assignActivity(activityId: secondActivity.activityId, to: home.projectId))
        _ = manager.addActivityToDailyPlan(activityId: firstActivity.activityId, sessionCount: 2)
        _ = manager.addActivityToDailyPlan(activityId: secondActivity.activityId, sessionCount: 1)
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )

        presenter.onViewAppear(delegate: TodayDelegate())
        #expect(!presenter.hasUnassignedPlannedActivities)
        presenter.selectProject(writing.projectId)

        #expect(presenter.deckPlanItems.map(\.activityId) == [firstActivity.activityId])
        #expect(presenter.sessionProgressLabel == "0 of 3")

        presenter.selectProject(home.projectId)

        #expect(presenter.deckPlanItems.map(\.activityId) == [secondActivity.activityId])
    }

    @Test func unassignedDeckAppearsOnlyWhenItHasPlannedActivities() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let activity = try #require(manager.createActivity(
            name: "Read a book",
            category: nil,
            colorToken: nil
        ))
        _ = manager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)
        let project = try #require(manager.createProject(name: "Reading"))
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )

        presenter.onViewAppear(delegate: TodayDelegate())
        #expect(presenter.hasUnassignedPlannedActivities)

        #expect(manager.assignActivity(activityId: activity.activityId, to: project.projectId))
        presenter.onViewAppear(delegate: TodayDelegate())

        #expect(!presenter.hasUnassignedPlannedActivities)
    }

    @Test func addingActivityFromSelectedProjectAssignsItToThatDeck() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let project = try #require(manager.createProject(name: "Writing"))
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectProject(project.projectId)

        presenter.saveActivity(
            ActivitySheetDraft(
                name: "Write report",
                category: .work,
                type: .session,
                checklistItems: [],
                sessionCount: 2,
                projectId: presenter.selectedProjectId,
                recurrence: nil
            )
        )

        let activity = try #require(manager.activities.first { $0.name == "Write report" })
        #expect(activity.projectId == project.projectId)
        #expect(presenter.deckPlanItems.map(\.activityId) == [activity.activityId])
    }

    @Test func choosingDifferentProjectForNewActivityOpensThatDeck() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let currentProject = try #require(manager.createProject(name: "Writing"))
        let destinationProject = try #require(manager.createProject(name: "Research"))
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectProject(currentProject.projectId)

        presenter.saveActivity(
            ActivitySheetDraft(
                name: "Read papers",
                category: .study,
                type: .session,
                checklistItems: [],
                sessionCount: 1,
                projectId: destinationProject.projectId,
                recurrence: nil
            )
        )

        let activity = try #require(manager.activities.first { $0.name == "Read papers" })
        #expect(presenter.selectedProjectId == destinationProject.projectId)
        #expect(presenter.deckPlanItems.map(\.activityId) == [activity.activityId])
    }

    @Test func projectSelectionAndDeckFilterPersistAcrossDayNavigation() throws {
        let fixture = projectHistoryFixture()
        let dependencies = Dependencies(
            config: .mock(isSignedIn: true, addLogging: false),
            snapshotOverride: fixture.snapshot
        )
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )

        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectProject(fixture.project.projectId)
        presenter.onPreviousDayPressed()

        #expect(presenter.selectedLocalDay == fixture.previousDay)
        #expect(presenter.selectedProjectId == fixture.project.projectId)
        #expect(presenter.deckPlanItems.map(\.activityId) == [fixture.secondActivity.activityId])
        #expect(presenter.sessionProgressLabel == "0 of 1")

        presenter.onNextDayPressed()

        #expect(presenter.selectedLocalDay == fixture.currentDay)
        #expect(presenter.deckPlanItems.map(\.activityId) == [
            fixture.firstActivity.activityId,
            fixture.secondActivity.activityId
        ])
        #expect(presenter.sessionProgressLabel == "0 of 2")
    }

    @Test func deletedSelectedProjectFallsBackToUnassignedDeck() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let activity = try #require(manager.activities.first)
        let project = try #require(manager.createProject(name: "Writing"))
        #expect(manager.assignActivity(activityId: activity.activityId, to: project.projectId))
        _ = manager.addActivityToDailyPlan(activityId: activity.activityId, sessionCount: 1)
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectProject(project.projectId)
        #expect(presenter.deckPlanItems.isEmpty)

        #expect(manager.deleteProject(projectId: project.projectId))
        presenter.onViewAppear(delegate: TodayDelegate())

        #expect(presenter.selectedProjectId == nil)
        #expect(presenter.selectedProjectTitle == "Other")
        #expect(presenter.deckPlanItems.map(\.activityId) == [activity.activityId])
    }

    @Test func startingFocusUsesTheLatestSelectedActivity() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: router
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()

        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == secondActivity.activityId)
        #expect(delegate.session.activityId == secondActivity.activityId)
    }

    @Test func selectedActivityReplacesAnUnstartedReadySession() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.onStartFocusPressed()
        let firstSession = try #require(focusManager.focusSessions.first)

        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()
        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == secondActivity.activityId)
        #expect(delegate.session.activityId == secondActivity.activityId)
        #expect(focusManager.focusSessions.count == 2)
        #expect(
            focusManager.focusSessions.first { $0.focusSessionId == firstSession.focusSessionId }?.state == .abandoned
        )
        #expect(focusManager.activeFocusSession?.activityId == secondActivity.activityId)
    }

    @Test func runningFocusSessionRemainsAuthoritativeForAnotherSelection() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
        let secondActivity = try #require(
            manager.createActivity(name: "Write report", category: .work, colorToken: "slateBlue")
        )
        _ = manager.addActivityToDailyPlan(
            activityId: ActivityModel.mock.activityId,
            sessionCount: 1
        )
        _ = manager.addActivityToDailyPlan(
            activityId: secondActivity.activityId,
            sessionCount: 1
        )

        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingTodayRouter()
        let presenter = TodayPresenter(interactor: interactor, router: router)
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.onStartFocusPressed()
        let firstSession = try #require(focusManager.focusSessions.first)
        _ = try focusManager.beginFocusSession(focusSessionId: firstSession.focusSessionId)

        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectNextPlanItem()
        presenter.onStartFocusPressed()

        let delegate = try #require(router.presentedFocusDelegate)
        #expect(delegate.activity.activityId == ActivityModel.mock.activityId)
        #expect(delegate.session.focusSessionId == firstSession.focusSessionId)
        #expect(focusManager.focusSessions.count == 1)
    }

}

@MainActor
extension TodayPresenterTests {
    @Test func archivedSpaceIsHiddenTodayButRemainsInPastDayDeck() throws {
        let fixture = projectHistoryFixture()
        let dependencies = Dependencies(
            config: .mock(isSignedIn: true, addLogging: false),
            snapshotOverride: fixture.snapshot
        )
        let manager = try #require(dependencies.container.resolve(TodayManager.self))
        let presenter = TodayPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: RecordingTodayRouter()
        )
        presenter.onViewAppear(delegate: TodayDelegate())
        presenter.selectProject(fixture.project.projectId)

        #expect(manager.setProjectArchived(projectId: fixture.project.projectId, isArchived: true))
        presenter.onViewAppear(delegate: TodayDelegate())
        #expect(presenter.projects.isEmpty)
        #expect(presenter.planItems.isEmpty)
        #expect(presenter.selectedProjectId == nil)
        #expect(presenter.sessionProgressLabel == "0 of 0")

        presenter.onPreviousDayPressed()
        #expect(presenter.projects.first?.projectId == fixture.project.projectId)
        presenter.selectProject(fixture.project.projectId)
        #expect(presenter.deckPlanItems.map(\.activityId) == [fixture.secondActivity.activityId])
        #expect(presenter.sessionProgressLabel == "0 of 1")

        presenter.onNextDayPressed()
        #expect(presenter.projects.isEmpty)
        #expect(presenter.planItems.isEmpty)
        #expect(manager.setProjectArchived(projectId: fixture.project.projectId, isArchived: false))
        presenter.onViewAppear(delegate: TodayDelegate())
        #expect(presenter.projects.first?.projectId == fixture.project.projectId)
        #expect(presenter.planItems.count == 2)
    }

#if MOCK
        @Test func focusDismissalRefreshesCompletedSessionsAndCredits() throws {
            let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
            let manager = try #require(dependencies.container.resolve(TodayManager.self))
            let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
            _ = manager.addActivityToDailyPlan(
                activityId: ActivityModel.mock.activityId,
                sessionCount: 1
            )
            let presenter = TodayPresenter(
                interactor: CoreInteractor(container: dependencies.container),
                router: RecordingTodayRouter()
            )
            presenter.onViewAppear(delegate: TodayDelegate())
            presenter.onStartFocusPressed()
            let session = try #require(focusManager.focusSessions.first)

            _ = try focusManager.beginFocusSession(focusSessionId: session.focusSessionId)
            _ = try focusManager.markFocusSessionCompleteForTesting(
                focusSessionId: session.focusSessionId
            )

            #expect(presenter.completedUnitCounts[ActivityModel.mock.activityId, default: 0] == 0)
            #expect(manager.rewardCredits == 0)

            presenter.onFocusViewDismissed()

            #expect(presenter.completedUnitCounts[ActivityModel.mock.activityId, default: 0] == 1)
            #expect(manager.rewardCredits == 1)

            let additional = try #require(focusManager.startFocusSession(activityId: ActivityModel.mock.activityId))
            _ = try focusManager.beginFocusSession(focusSessionId: additional.focusSessionId)
            _ = try focusManager.markFocusSessionCompleteForTesting(focusSessionId: additional.focusSessionId)
            presenter.onFocusViewDismissed()

            let item = try #require(presenter.planItems.first)
            #expect(presenter.completedCount(for: item) == 2)
            #expect(presenter.remainingUnitCount(for: item) == 0)
            #expect(presenter.sessionProgressLabel == "2 of 1")
            #expect(manager.rewardCredits == 2)
        }

        @Test func focusDelegateCarriesDismissActionThatRefreshesToday() throws {
            let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
            let manager = try #require(dependencies.container.resolve(TodayManager.self))
            let focusManager = try #require(dependencies.container.resolve(FocusManager.self))
            _ = manager.addActivityToDailyPlan(
                activityId: ActivityModel.mock.activityId,
                sessionCount: 1
            )
            let router = RecordingTodayRouter()
            let presenter = TodayPresenter(
                interactor: CoreInteractor(container: dependencies.container),
                router: router
            )
            presenter.onViewAppear(delegate: TodayDelegate())
            presenter.onStartFocusPressed()

            let delegate = try #require(router.presentedFocusDelegate)
            let onDismiss = try #require(delegate.onDismiss)
            let session = try #require(focusManager.focusSessions.first)
            _ = try focusManager.beginFocusSession(focusSessionId: session.focusSessionId)
            _ = try focusManager.markFocusSessionCompleteForTesting(
                focusSessionId: session.focusSessionId
            )

            onDismiss()

            #expect(presenter.completedUnitCounts[ActivityModel.mock.activityId, default: 0] == 1)
            #expect(manager.rewardCredits == 1)
        }
    #endif
}

@MainActor
private final class RecordingTodayRouter: TodayRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this recording test double") }
    private(set) var didShowStreak = false
    private(set) var didShowProjectManagement = false
    private(set) var presentedFocusDelegate: FocusDelegate?

    func showStarterActivityView(delegate: StarterActivityDelegate) { }
    func showDailyPlanView(delegate: DailyPlanDelegate) { }
    func showFocusView(delegate: FocusDelegate) {
        presentedFocusDelegate = delegate
    }

    func showStreakView(delegate: StreakDelegate) {
        didShowStreak = true
    }

    func showProjectManagementView(delegate: TodayProjectManagementDelegate) {
        didShowProjectManagement = true
    }

    func showDevSettingsView() { }
}
