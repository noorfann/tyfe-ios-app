import Foundation

@MainActor
protocol TodoManaging {
    var tasks: [TodoTaskModel] { get }
    var history: [TodoCompletionRecord] { get }
    func prepare() throws
    func save(_ draft: TodoDraft) throws
    func setCompleted(taskId: String, completed: Bool) throws
    func toggleItem(taskId: String, itemId: String) throws
}
