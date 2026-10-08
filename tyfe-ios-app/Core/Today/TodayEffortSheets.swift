import SwiftUI

struct TodayEffortSheets: ViewModifier {
    @Bindable var presenter: TodayEffortPresenter
    let projects: [ProjectModel]

    func body(content: Content) -> some View {
        content
            .tyfeBottomSheet(
                isPresented: $presenter.isTodoFormPresented,
                detents: presenter.todoDraft.taskId == nil ? [.fraction(0.8)] : [.large], title: "To Do"
            ) {
                TodoFormView(draft: $presenter.todoDraft, projects: projects, onSave: presenter.saveTodo)
            }
            .tyfeBottomSheet(
                isPresented: $presenter.isHabitFormPresented,
                detents: presenter.habitDraft.habitId == nil ? [.fraction(0.8)] : [.large], title: "Habit"
            ) {
                HabitFormView(draft: $presenter.habitDraft, projects: projects, onSave: presenter.saveHabit)
            }
            .tyfeBottomSheet(
                isPresented: $presenter.isHabitDetailPresented, detents: [.large], title: "Habit history",
                onDismiss: presenter.onHabitDetailDismissed
            ) {
                if let habit = presenter.selectedHabit {
                    HabitDetailView(presenter: presenter, habit: habit)
                }
            }
    }
}
