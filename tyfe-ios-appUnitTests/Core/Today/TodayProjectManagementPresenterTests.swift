import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct TodayProjectManagementPresenterTests {

    @Test func creatingAndEditingProjectPersistsAppearance() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        var createdProjectId: String?
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: RecordingProjectManagementRouter(),
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { createdProjectId = $0 },
                onProjectManagementChanged: { }
            )
        )
        presenter.onViewAppear()

        #expect(presenter.saveProject(
            projectId: nil,
            name: "Reading",
            colorToken: "#12aBcD"
        ))

        let projectId = try #require(createdProjectId)
        #expect(interactor.phase1SelectedProjectId == projectId)
        #expect(presenter.projects.first?.colorToken == "#12ABCD")
        #expect(ProjectColorOption.title(for: presenter.projects.first?.resolvedColorToken) == "Custom color #12ABCD")

        #expect(presenter.saveProject(
            projectId: projectId,
            name: "Learning",
            colorToken: "#AaBbCc"
        ))
        #expect(presenter.projects.first?.name == "Learning")
        #expect(presenter.projects.first?.colorToken == "#AABBCC")
        #expect(ProjectColorOption.title(for: presenter.projects.first?.resolvedColorToken) == "Custom color #AABBCC")
    }

    @Test func projectIsDeletedOnlyAfterConfirmation() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        let router = RecordingProjectManagementRouter()
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: router,
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { _ in },
                onProjectManagementChanged: { }
            )
        )
        let project = try #require(interactor.createPhase1Project(
            name: "Writing",
            colorToken: "teal"
        ))
        let activity = try #require(interactor.phase1Activities.first)
        #expect(interactor.assignPhase1Activity(activityId: activity.activityId, to: project.projectId))
        presenter.onViewAppear()

        presenter.onDeleteProjectPressed(project)

        #expect(router.confirmationTitle == "Delete Writing?")
        #expect(interactor.phase1Projects.contains(where: { $0.projectId == project.projectId }))

        router.confirmDeletion()

        #expect(interactor.phase1Projects.isEmpty)
        #expect(interactor.phase1Activities.first?.projectId == nil)
        #expect(presenter.projects.isEmpty)
    }

    @Test func reorderingSpacesRefreshesManagementOrder() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        var changeCount = 0
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: RecordingProjectManagementRouter(),
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { _ in },
                onProjectManagementChanged: { changeCount += 1 }
            )
        )
        let first = try #require(interactor.createPhase1Project(name: "First", colorToken: "teal"))
        let second = try #require(interactor.createPhase1Project(name: "Second", colorToken: "teal"))
        let third = try #require(interactor.createPhase1Project(name: "Third", colorToken: "teal"))
        presenter.onViewAppear()

        #expect(presenter.reorderProject(projectId: first.projectId, toIndex: 2))

        let expectedOrder = [second.projectId, third.projectId, first.projectId]
        #expect(presenter.projects.map(\.projectId) == expectedOrder)
        #expect(interactor.phase1Projects.map(\.projectId) == expectedOrder)
        #expect(changeCount == 1)
    }

    @Test func movingActiveSpacesReordersAroundArchivedSpaces() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        var changeCount = 0
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: RecordingProjectManagementRouter(),
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { _ in },
                onProjectManagementChanged: { changeCount += 1 }
            )
        )
        let first = try #require(interactor.createPhase1Project(name: "First", colorToken: "teal"))
        let second = try #require(interactor.createPhase1Project(name: "Second", colorToken: "teal"))
        let third = try #require(interactor.createPhase1Project(name: "Third", colorToken: "teal"))
        #expect(interactor.setPhase1ProjectArchived(projectId: second.projectId, isArchived: true))
        presenter.onViewAppear()

        #expect(presenter.moveActiveProjects(fromOffsets: IndexSet(integer: 0), toOffset: 2))

        #expect(presenter.activeProjects.map(\.projectId) == [third.projectId, first.projectId])
        #expect(presenter.archivedProjects.map(\.projectId) == [second.projectId])
        #expect(interactor.phase1Projects.map(\.projectId) == [
            second.projectId, third.projectId, first.projectId
        ])
        #expect(changeCount == 1)
    }

    @Test func movingActiveSpacesRejectsOutOfRangeOffsets() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        var changeCount = 0
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: RecordingProjectManagementRouter(),
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { _ in },
                onProjectManagementChanged: { changeCount += 1 }
            )
        )
        try #require(interactor.createPhase1Project(name: "First", colorToken: "teal"))
        try #require(interactor.createPhase1Project(name: "Second", colorToken: "teal"))
        presenter.onViewAppear()

        #expect(!presenter.moveActiveProjects(fromOffsets: IndexSet(integer: 2), toOffset: 0))
        #expect(!presenter.moveActiveProjects(fromOffsets: IndexSet(integer: 0), toOffset: 3))
        #expect(changeCount == 0)
    }

    @Test func archivingAndRestoringMovesSpaceBetweenSections() throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        var changeCount = 0
        let presenter = TodayProjectManagementPresenter(
            interactor: interactor,
            router: RecordingProjectManagementRouter(),
            delegate: TodayProjectManagementDelegate(
                onProjectCreated: { _ in },
                onProjectManagementChanged: { changeCount += 1 }
            )
        )
        let project = try #require(interactor.createPhase1Project(name: "Writing", colorToken: "teal"))
        presenter.onViewAppear()

        presenter.setProjectArchived(project, isArchived: true)
        #expect(presenter.activeProjects.isEmpty)
        #expect(presenter.archivedProjects.map(\.projectId) == [project.projectId])
        #expect(changeCount == 1)

        presenter.setProjectArchived(try #require(presenter.archivedProjects.first), isArchived: false)
        #expect(presenter.activeProjects.map(\.projectId) == [project.projectId])
        #expect(presenter.archivedProjects.isEmpty)
        #expect(changeCount == 2)
    }
}

@MainActor
private final class RecordingProjectManagementRouter: TodayProjectManagementRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this recording test double") }
    private(set) var confirmationTitle: String?
    private var onConfirm: (@MainActor @Sendable () -> Void)?

    func confirmProjectDeletion(
        named projectName: String,
        onConfirm: @escaping @MainActor @Sendable () -> Void
    ) {
        confirmationTitle = "Delete \(projectName)?"
        self.onConfirm = onConfirm
    }

    func confirmDeletion() {
        onConfirm?()
    }
}
