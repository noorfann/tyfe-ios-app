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

    var activeProjects: [ProjectModel] {
        projects.filter { !$0.isArchived }
    }

    var archivedProjects: [ProjectModel] {
        projects.filter(\.isArchived)
    }

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

    func setProjectArchived(_ project: ProjectModel, isArchived: Bool) {
        guard interactor.setPhase1ProjectArchived(
            projectId: project.projectId,
            isArchived: isArchived
        ) else { return }
        reload()
        delegate.onProjectManagementChanged()
        interactor.trackEvent(event: isArchived ? Event.archiveProject : Event.restoreProject)
    }

    @discardableResult
    func reorderProject(projectId: String, toIndex: Int) -> Bool {
        guard let currentIndex = projects.firstIndex(where: { $0.projectId == projectId }) else { return false }
        guard currentIndex != toIndex else { return true }
        guard interactor.reorderPhase1Project(projectId: projectId, toIndex: toIndex) else { return false }
        reload()
        delegate.onProjectManagementChanged()
        interactor.trackEvent(event: Event.reorderProject)
        return true
    }

    @discardableResult
    func moveActiveProjects(fromOffsets source: IndexSet, toOffset destination: Int) -> Bool {
        let orderedActiveProjects = activeProjects
        guard source.count == 1,
              let sourceIndex = source.first,
              orderedActiveProjects.indices.contains(sourceIndex),
              destination >= 0,
              destination <= orderedActiveProjects.count else {
            return false
        }

        let movedProject = orderedActiveProjects[sourceIndex]
        var reorderedProjects = orderedActiveProjects
        reorderedProjects.move(fromOffsets: source, toOffset: destination)
        guard let movedIndex = reorderedProjects.firstIndex(where: {
            $0.projectId == movedProject.projectId
        }) else {
            return false
        }

        var remainingProjects = projects
        remainingProjects.removeAll { $0.projectId == movedProject.projectId }
        let targetIndex: Int
        if movedIndex + 1 < reorderedProjects.count {
            guard let nextProjectIndex = remainingProjects.firstIndex(where: {
                $0.projectId == reorderedProjects[movedIndex + 1].projectId
            }) else {
                return false
            }
            targetIndex = nextProjectIndex
        } else {
            targetIndex = remainingProjects.count
        }

        return reorderProject(projectId: movedProject.projectId, toIndex: targetIndex)
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
        case archiveProject
        case restoreProject
        case reorderProject

        var eventName: String {
            switch self {
            case .onAppear: return "Today_ProjectManagement_Appear"
            case .onDisappear: return "Today_ProjectManagement_Disappear"
            case .createProject: return "Today_Project_Create"
            case .updateProject: return "Today_Project_Rename"
            case .deleteProject: return "Today_Project_Delete"
            case .archiveProject: return "Today_Project_Archive"
            case .restoreProject: return "Today_Project_Restore"
            case .reorderProject: return "Today_Project_Reorder"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .createProject, .updateProject, .deleteProject, .archiveProject,
                    .restoreProject, .reorderProject:
                return nil
            }
        }

        var type: LogType { .analytic }
    }
}
