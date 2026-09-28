import Foundation

extension CoreInteractor {

    @discardableResult
    func createPhase1Project(name: String, colorToken: String) -> ProjectModel? {
        todayManager.createProject(name: name, colorToken: colorToken)
    }

    @discardableResult
    func renamePhase1Project(
        projectId: String,
        name: String,
        colorToken: String
    ) -> ProjectModel? {
        todayManager.renameProject(
            projectId: projectId,
            name: name,
            colorToken: colorToken
        )
    }

    @discardableResult
    func deletePhase1Project(projectId: String) -> Bool {
        todayManager.deleteProject(projectId: projectId)
    }

    @discardableResult
    func setPhase1ProjectArchived(projectId: String, isArchived: Bool) -> Bool {
        todayManager.setProjectArchived(projectId: projectId, isArchived: isArchived)
    }

    @discardableResult
    func reorderPhase1Project(projectId: String, toIndex: Int) -> Bool {
        todayManager.reorderProject(projectId: projectId, toIndex: toIndex)
    }

    @discardableResult
    func assignPhase1Activity(activityId: String, to projectId: String?) -> Bool {
        todayManager.assignActivity(activityId: activityId, to: projectId)
    }
}
