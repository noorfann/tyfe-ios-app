import SwiftUI

struct TodayProjectManagementDelegate {
    let onProjectCreated: (String) -> Void
    let onProjectManagementChanged: () -> Void

    var eventParameters: [String: Any]? { nil }
}

@Observable
@MainActor
final class TodayProjectManagementPresenter {

    private let interactor: TodayInteractor
    private let router: TodayProjectManagementRouter
    private let delegate: TodayProjectManagementDelegate

    private(set) var projects: [ProjectModel] = []

    init(
        interactor: TodayInteractor,
        router: TodayProjectManagementRouter,
        delegate: TodayProjectManagementDelegate
    ) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
    }

    func onViewAppear() {
        reload()
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func saveProject(
        projectId: String?,
        name: String,
        colorToken: String
    ) -> Bool {
        let normalizedColorToken = ProjectColorOption.normalizedToken(colorToken)
        let project: ProjectModel?
        if let projectId {
            project = interactor.renamePhase1Project(
                projectId: projectId,
                name: name,
                colorToken: normalizedColorToken
            )
        } else {
            project = interactor.createPhase1Project(
                name: name,
                colorToken: normalizedColorToken
            )
        }

        guard let project else { return false }
        reload()

        if projectId == nil {
            interactor.setPhase1SelectedProjectId(project.projectId)
            delegate.onProjectCreated(project.projectId)
            interactor.trackEvent(event: Event.createProject)
        } else {
            delegate.onProjectManagementChanged()
            interactor.trackEvent(event: Event.updateProject)
        }
        return true
    }

    func onDeleteProjectPressed(_ project: ProjectModel) {
        router.confirmProjectDeletion(named: project.name) { [weak self] in
            self?.deleteProject(project.projectId)
        }
    }

    private func reload() {
        projects = interactor.phase1Projects
    }

    private func deleteProject(_ projectId: String) {
        guard interactor.deletePhase1Project(projectId: projectId) else { return }
        reload()
        delegate.onProjectManagementChanged()
        interactor.trackEvent(event: Event.deleteProject)
    }
}

extension TodayProjectManagementPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: TodayProjectManagementDelegate)
        case onDisappear(delegate: TodayProjectManagementDelegate)
        case createProject
        case updateProject
        case deleteProject

        var eventName: String {
            switch self {
            case .onAppear: return "Today_ProjectManagement_Appear"
            case .onDisappear: return "Today_ProjectManagement_Disappear"
            case .createProject: return "Today_Project_Create"
            case .updateProject: return "Today_Project_Rename"
            case .deleteProject: return "Today_Project_Delete"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createProject, .updateProject, .deleteProject:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
