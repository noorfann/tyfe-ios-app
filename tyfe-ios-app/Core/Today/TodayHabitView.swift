import SwiftUI
import SwiftfulUI

struct TodayHabitView: View {
    let presenter: TodayEffortPresenter
    let projectId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeMetricCardView(
                title: "Habits today", value: presenter.habitProgress(in: projectId),
                systemImage: "leaf.fill", accent: TyfeEditorialPalette.teal
            )
            Text(presenter.showsArchivedHabits ? "Show active Habits" : "Archived Habits")
                .font(TyfeTypography.caption).frame(minHeight: 44)
                .asButton(.press, action: presenter.toggleArchivedHabits)
            if presenter.habits(in: projectId).isEmpty {
                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        Text(presenter.showsArchivedHabits ? "No archived Habits." : "Small things, often.")
                            .font(TyfeTypography.displayCompact)
                        Text("One check for each scheduled day. Your history grows one tile at a time.")
                            .font(TyfeTypography.interface).foregroundStyle(TyfeEditorialPalette.muted)
                        TyfeActionButtonView(title: "Add Habit", systemImage: "plus") { presenter.addHabit(in: projectId) }
                    }
                }
            }
            ForEach(presenter.habits(in: projectId)) { habit in
                HabitCardView(
                    habit: habit, occurrence: presenter.occurrence(for: habit.id),
                    streak: presenter.streak(for: habit.id), weeks: presenter.heatmap(for: habit),
                    scheduleLabel: habit.revision(on: presenter.today)?.schedule.displaySummary ?? "Archived",
                    onCheck: { presenter.toggleHabit(habit) }, onSkip: { presenter.toggleSkip(habit) },
                    onDetail: { presenter.showHabit(habit) }
                )
            }
        }
        .accessibilityIdentifier("today-habit-page")
    }
}
