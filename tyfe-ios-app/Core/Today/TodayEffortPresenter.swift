import SwiftUI

@Observable
@MainActor
final class TodayEffortPresenter {
    private let interactor: TodayInteractor
    private let router: TodayRouter
    private(set) var tasks: [TodoTaskModel] = []
    private(set) var history: [TodoCompletionRecord] = []
    private(set) var habits: [HabitModel] = []
    private(set) var occurrences: [HabitOccurrence] = []
    private(set) var today: LocalDay
    private(set) var preparationFailed = false
    var todoDraft = TodoDraft()
    var habitDraft = HabitDraft()
    var isTodoFormPresented = false
    var isHabitFormPresented = false
    var isHabitDetailPresented = false
    var showsCompletedTasks = false
    var showsArchivedHabits = false
    private(set) var selectedHabitId: String?
    private(set) var selectedMonth: LocalDay
    private var pendingHabitEdit = false

    init(interactor: TodayInteractor, router: TodayRouter) {
        self.interactor = interactor
        self.router = router
        let currentDay = interactor.phase1CurrentLocalDay
        today = currentDay
        selectedMonth = currentDay
    }

    func reload() {
        interactor.synchronizeCurrentDay()
        tasks = interactor.todoTasks
        history = interactor.todoHistory
        habits = interactor.habits
        occurrences = interactor.habitOccurrences
        today = interactor.phase1CurrentLocalDay
        preparationFailed = interactor.effortPreparationFailed
    }

    func tasks(in projectId: String?, completed: Bool) -> [TodoTaskModel] {
        tasks.filter { $0.projectId == projectId && $0.isCompleted == completed }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func history(in projectId: String?) -> [TodoCompletionRecord] {
        history.filter { record in
            let space = interactor.phase1Projects.contains { $0.id == record.projectId } ? record.projectId : nil
            return space == projectId
        }.sorted { $0.completedAt > $1.completedAt }
    }

    func habits(in projectId: String?) -> [HabitModel] {
        habits.filter { $0.projectId == projectId && $0.isActive(on: today) != showsArchivedHabits }
            .sorted { first, second in
                let firstDue = occurrence(for: first.id) != nil
                let secondDue = occurrence(for: second.id) != nil
                return firstDue == secondDue ? first.createdAt < second.createdAt : firstDue
            }
    }

    func occurrence(for habitId: String) -> HabitOccurrence? {
        occurrences.first { $0.habitId == habitId && $0.localDay == today }
    }

    func streak(for habitId: String) -> HabitStreakSummary {
        HabitStreakSummary(occurrences: occurrences.filter { $0.habitId == habitId }, today: today)
    }

    func habitProgress(in projectId: String?) -> String {
        let ids = Set(habits.filter { $0.projectId == projectId }.map(\.id))
        let due = occurrences.filter { ids.contains($0.habitId) && $0.localDay == today && $0.status != .skipped }
        let skipped = occurrences.filter { ids.contains($0.habitId) && $0.localDay == today && $0.status == .skipped }.count
        return "\(due.filter { $0.status == .completed }.count) of \(due.count) · \(skipped) skipped"
    }

    func addTodo(in projectId: String?) {
        todoDraft = TodoDraft(projectId: projectId)
        isTodoFormPresented = true
    }

    func editTodo(_ task: TodoTaskModel) {
        todoDraft = TodoDraft(task: task)
        isTodoFormPresented = true
        interactor.trackEvent(eventName: "Todo_Edit_Open", parameters: nil, type: .analytic)
    }

    func saveTodo() {
        perform {
            try interactor.saveTodo(todoDraft)
            isTodoFormPresented = false
        }
    }

    func toggleTodo(_ task: TodoTaskModel) {
        perform { try interactor.setTodoCompleted(taskId: task.id, completed: !task.isCompleted) }
    }

    func toggleItem(taskId: String, itemId: String) {
        perform { try interactor.toggleTodoItem(taskId: taskId, itemId: itemId) }
    }

    func addHabit(in projectId: String?) {
        habitDraft = HabitDraft(projectId: projectId)
        isHabitFormPresented = true
    }

    func editHabit(_ habit: HabitModel) {
        habitDraft = HabitDraft(habit: habit)
        pendingHabitEdit = isHabitDetailPresented
        isHabitDetailPresented = false
        if !pendingHabitEdit { isHabitFormPresented = true }
        interactor.trackEvent(eventName: "Habit_Edit_Open", parameters: nil, type: .analytic)
    }

    func onHabitDetailDismissed() {
        guard pendingHabitEdit else { return }
        pendingHabitEdit = false
        isHabitFormPresented = true
    }

    func toggleTaskHistory() {
        showsCompletedTasks.toggle()
        interactor.trackEvent(eventName: "Todo_History_Toggle", parameters: nil, type: .analytic)
    }

    func toggleArchivedHabits() {
        showsArchivedHabits.toggle()
        interactor.trackEvent(eventName: "Habit_Archives_Toggle", parameters: nil, type: .analytic)
    }

    func saveHabit() {
        perform {
            try interactor.saveHabit(habitDraft)
            isHabitFormPresented = false
        }
    }

    func toggleHabit(_ habit: HabitModel) {
        guard let occurrence = occurrence(for: habit.id) else { return }
        setHabit(habit, status: occurrence.status == .completed ? .pending : .completed)
    }

    func toggleSkip(_ habit: HabitModel) {
        guard let occurrence = occurrence(for: habit.id) else { return }
        setHabit(habit, status: occurrence.status == .skipped ? .pending : .skipped)
    }

    private func setHabit(_ habit: HabitModel, status: HabitDayStatus) {
        perform { try interactor.setHabitStatus(habitId: habit.id, day: today, status: status) }
    }

    func showHabit(_ habit: HabitModel) {
        selectedHabitId = habit.id
        selectedMonth = today
        isHabitDetailPresented = true
        interactor.trackEvent(eventName: "Habit_Detail_Open", parameters: nil, type: .analytic)
    }

    var selectedHabit: HabitModel? { habits.first { $0.id == selectedHabitId } }

    var canViewPreviousMonth: Bool {
        guard let habit = selectedHabit else { return false }
        let first = LocalDay(containing: habit.createdAt, calendar: localCalendar)
        return selectedMonth.year > first.year || (selectedMonth.year == first.year && selectedMonth.month > first.month)
    }

    var canViewNextMonth: Bool { selectedMonth.year < today.year || (selectedMonth.year == today.year && selectedMonth.month < today.month) }

    func moveMonth(by offset: Int) {
        guard offset < 0 ? canViewPreviousMonth : canViewNextMonth,
              let date = localCalendar.date(byAdding: .month, value: offset, to: selectedMonth.startDate) else { return }
        selectedMonth = LocalDay(containing: date, calendar: localCalendar)
        interactor.trackEvent(eventName: "Habit_Calendar_Move", parameters: nil, type: .analytic)
    }

    func heatmap(for habit: HabitModel, fullHistory: Bool = false) -> [HabitHeatmapWeek] {
        let sixMonthsAgo = localCalendar.date(byAdding: .month, value: -6, to: today.startDate) ?? today.adding(days: -181).startDate
        let firstDay = fullHistory ? LocalDay(containing: habit.createdAt, calendar: localCalendar)
            : LocalDay(containing: sixMonthsAgo, calendar: localCalendar).adding(days: 1)
        let first = firstDay.adding(days: -(ActivityRecurrenceModel.isoWeekday(for: firstDay).map { $0 - 1 } ?? 0))
        var weeks: [HabitHeatmapWeek] = []
        var day = first
        let statuses = Dictionary(uniqueKeysWithValues: occurrences.filter { $0.habitId == habit.id }.map { ($0.localDay.id, $0.status) })
        while day.startDate <= today.startDate {
            let days = (0..<7).map { offset -> HabitGridDay in
                let date = day.adding(days: offset)
                let status: HabitDayStatus = date.startDate > today.startDate ? .future : statuses[date.id] ?? .unscheduled
                return HabitGridDay(day: date, status: status, isToday: date == today)
            }
            weeks.append(HabitHeatmapWeek(days: days))
            day = day.adding(days: 7)
        }
        return weeks
    }

    func calendarDays(for habit: HabitModel) -> [HabitGridDay] {
        let month = LocalDay(year: selectedMonth.year, month: selectedMonth.month, day: 1, timeZoneIdentifier: today.timeZoneIdentifier)
        let leading = (ActivityRecurrenceModel.isoWeekday(for: month) ?? 1) - 1
        let start = month.adding(days: -leading)
        let count = localCalendar.range(of: .day, in: .month, for: month.startDate)?.count ?? 30
        let cells = ((leading + count + 6) / 7) * 7
        let statuses = Dictionary(uniqueKeysWithValues: occurrences.filter { $0.habitId == habit.id }.map { ($0.localDay.id, $0.status) })
        return (0..<cells).map { offset in
            let day = start.adding(days: offset)
            return HabitGridDay(
                day: day, status: day.startDate > today.startDate ? .future : statuses[day.id] ?? .unscheduled,
                isToday: day == today, isInMonth: day.month == selectedMonth.month
            )
        }
    }

    private var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: today.timeZoneIdentifier) ?? .current
        return calendar
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            reload()
        } catch {
            let message = (error as? RewardCreditLedgerError) == .insufficientCredits
                ? "Undo needs the credits earned from this completion. Your balance is too low."
                : error.localizedDescription
            router.showSimpleAlert(title: "Could not save", subtitle: message)
            interactor.trackEvent(eventName: "Effort_Action_Fail", parameters: nil, type: .warning)
        }
    }
}
