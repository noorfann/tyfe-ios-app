import SwiftUI
import SwiftfulUI

struct TodayTodoView: View {
    let presenter: TodayEffortPresenter
    let projectId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeMetricCardView(
                title: "To Do", value: "\(presenter.tasks(in: projectId, completed: true).count) done · \(presenter.tasks(in: projectId, completed: false).count) open",
                systemImage: "checklist", accent: TyfeEditorialPalette.saffron
            )
            if presenter.tasks(in: projectId, completed: false).isEmpty {
                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        Text("Make room for what's next.").font(TyfeTypography.displayCompact)
                        Text("Add a task. It stays here until you're done.")
                            .font(TyfeTypography.interface).foregroundStyle(TyfeEditorialPalette.muted)
                        TyfeActionButtonView(title: "Add To Do", systemImage: "plus") { presenter.addTodo(in: projectId) }
                    }
                }
            }
            ForEach(presenter.tasks(in: projectId, completed: false)) { task in taskCard(task) }
            Text(presenter.showsCompletedTasks ? "Hide completed tasks and history" : "Completed tasks and history")
                .font(TyfeTypography.interfaceStrong).frame(minHeight: 44)
                .asButton(.press, action: presenter.toggleTaskHistory)
                .accessibilityIdentifier("todo-history-toggle")
            if presenter.showsCompletedTasks {
                ForEach(presenter.tasks(in: projectId, completed: true)) { task in taskCard(task) }
                ForEach(presenter.history(in: projectId)) { record in
                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text(record.title).font(TyfeTypography.interfaceStrong)
                        Text("\(record.completedAt.formatted(date: .abbreviated, time: .shortened))\(record.undoneAt == nil ? "" : " · Undone")")
                            .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                if presenter.history(in: projectId).isEmpty {
                    Text("No completed tasks yet.").font(TyfeTypography.interface)
                }
            }
        }
        .accessibilityIdentifier("today-todo-page")
    }

    private func taskCard(_ task: TodoTaskModel) -> some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .top, spacing: TyfeSpacing.control) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2).frame(minWidth: 44, minHeight: 44)
                        .foregroundStyle(task.isCompleted ? TyfeEditorialPalette.success : TyfeEditorialPalette.ink)
                        .asButton(.press) { presenter.toggleTodo(task) }
                        .disabled(!task.isCompleted && !task.items.isEmpty)
                        .accessibilityLabel(task.isCompleted ? "Reopen \(task.title)" : "Complete \(task.title)")
                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text(task.title).font(TyfeTypography.interfaceStrong).strikethrough(task.isCompleted)
                        Text(task.hasEarnedAward ? "Already rewarded" : task.creditValue.creditLabel)
                            .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "pencil")
                        .frame(minWidth: 44, minHeight: 44)
                        .asButton(.press) { presenter.editTodo(task) }
                        .accessibilityLabel("Edit \(task.title)")
                }
                ForEach(task.items) { item in
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: item.isCompleted ? "checkmark.square.fill" : "square")
                        Text(item.title).strikethrough(item.isCompleted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(TyfeTypography.interface).frame(minHeight: 44)
                    .asButton(.press) { presenter.toggleItem(taskId: task.id, itemId: item.id) }
                    .accessibilityLabel(item.title)
                    .accessibilityValue(item.isCompleted ? "Completed" : "Incomplete")
                }
            }
        }
    }
}
