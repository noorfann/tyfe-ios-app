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
