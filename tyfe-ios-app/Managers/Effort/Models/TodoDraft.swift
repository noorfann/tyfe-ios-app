import Foundation

struct TodoDraft {
    var taskId: String?
    var title: String = ""
    var projectId: String?
    var items: [TodoChecklistItem] = []
    var creditValue: ChecklistCreditValue = .halfCredit

    init(task: TodoTaskModel? = nil, projectId: String? = nil) {
        taskId = task?.id
        title = task?.title ?? ""
        self.projectId = task?.projectId ?? projectId
        items = task?.items ?? []
        creditValue = task?.creditValue ?? .halfCredit
    }
}
