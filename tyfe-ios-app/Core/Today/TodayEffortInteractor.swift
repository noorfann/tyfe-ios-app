import Foundation

@MainActor
protocol TodayEffortInteractor: GlobalInteractor {
    var todoTasks: [TodoTaskModel] { get }
    var todoHistory: [TodoCompletionRecord] { get }
    var habits: [HabitModel] { get }
    var habitOccurrences: [HabitOccurrence] { get }
    var effortPreparationFailed: Bool { get }
    func saveTodo(_ draft: TodoDraft) throws
    func setTodoCompleted(taskId: String, completed: Bool) throws
    func toggleTodoItem(taskId: String, itemId: String) throws
    func saveHabit(_ draft: HabitDraft) throws
    func setHabitStatus(habitId: String, day: LocalDay, status: HabitDayStatus) throws
}

extension CoreInteractor {
    var todoTasks: [TodoTaskModel] { todoManager.tasks }
    var todoHistory: [TodoCompletionRecord] { todoManager.history }
    var habits: [HabitModel] { habitManager.habits }
    var habitOccurrences: [HabitOccurrence] { habitManager.occurrences }
    var effortPreparationFailed: Bool { todoManager.preparationFailed }

    func saveTodo(_ draft: TodoDraft) throws { try todoManager.save(draft) }
    func setTodoCompleted(taskId: String, completed: Bool) throws { try todoManager.setCompleted(taskId: taskId, completed: completed) }
    func toggleTodoItem(taskId: String, itemId: String) throws { try todoManager.toggleItem(taskId: taskId, itemId: itemId) }

    func saveHabit(_ draft: HabitDraft) throws {
        try habitManager.save(draft)
        reconcileEffortStreak()
    }

    func setHabitStatus(habitId: String, day: LocalDay, status: HabitDayStatus) throws {
        try habitManager.setStatus(habitId: habitId, day: day, status: status)
        reconcileEffortStreak()
    }

    func reconcileEffortStreak() {
        do { try effortStreakManager.reconcile() } catch {
            trackEvent(eventName: "Effort_StreakReconcile_Fail", parameters: nil, type: .severe)
        }
    }
}
