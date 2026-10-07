import SwiftUI
import SwiftfulUI

struct HabitDetailView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presenter: TodayEffortPresenter
    let habit: HabitModel

    private var accent: Color { ProjectColorOption.color(for: habit.colorToken) }

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            HStack(alignment: .top) {
                Label(habit.title, systemImage: habit.iconToken)
                    .font(TyfeTypography.displayCompact).frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "pencil").frame(minWidth: 44, minHeight: 44)
                    .asButton(.press) { presenter.editHabit(habit) }
                    .accessibilityLabel("Edit Habit")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: TyfeSpacing.control) { streakCounters }
                VStack(alignment: .leading, spacing: TyfeSpacing.control) { streakCounters }
            }
            TyfeSurfaceView(role: .paper) {
                ScrollView(.horizontal) {
                    HabitHeatmapView(weeks: presenter.heatmap(for: habit, fullHistory: true), accent: accent)
                        .frame(width: max(280, CGFloat(presenter.heatmap(for: habit, fullHistory: true).count) * 12))
                }
            }
            monthCalendar
            Text("Filled: completed · Outline: missed · Dash: skipped · Faint: unscheduled or future. Past days are read-only.")
                .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
            if let occurrence = presenter.occurrence(for: habit.id) {
                TyfeActionButtonView(
                    title: occurrence.status == .completed ? "Undo today" : "Complete today", systemImage: "checkmark"
                ) { presenter.toggleHabit(habit) }
                TyfeActionButtonView(
                    title: occurrence.status == .skipped ? "Undo skip" : "Skip today", systemImage: "minus", role: .secondary
                ) { presenter.toggleSkip(habit) }
            }
        }
        .accessibilityIdentifier("habit-detail")
    }

    @ViewBuilder private var streakCounters: some View {
        Label("\(presenter.streak(for: habit.id).current) current", systemImage: "flame")
        Label("\(presenter.streak(for: habit.id).best) best", systemImage: "star")
    }

    private var monthCalendar: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(spacing: TyfeSpacing.control) {
                HStack {
                    Image(systemName: "chevron.left").frame(minWidth: 44, minHeight: 44)
                        .asButton(.press) { presenter.moveMonth(by: -1) }
                        .disabled(!presenter.canViewPreviousMonth).accessibilityLabel("Previous month")
                    Text(presenter.selectedMonth.startDate.formatted(.dateTime.month(.wide).year()))
                        .font(TyfeTypography.interfaceStrong).frame(maxWidth: .infinity)
                    Image(systemName: "chevron.right").frame(minWidth: 44, minHeight: 44)
                        .asButton(.press) { presenter.moveMonth(by: 1) }
                        .disabled(!presenter.canViewNextMonth).accessibilityLabel("Next month")
                }
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        ForEach(presenter.calendarDays(for: habit).filter(\.isInMonth)) { day in
                            Text("\(day.day.day): \(day.status.label)")
                                .font(TyfeTypography.interface).accessibilityLabel(day.accessibilityLabel)
                        }
                    }
                } else {
                    calendarGrid
                }
            }
        }
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: TyfeSpacing.small) {
                    ForEach(1...7, id: \.self) { weekday in
                        Text(ActivityRecurrenceModel.weekdayShortName(forISO: weekday))
                            .font(TyfeTypography.caption).accessibilityHidden(true)
                    }
                    ForEach(presenter.calendarDays(for: habit)) { day in
                        Text(String(day.day.day))
                            .font(TyfeTypography.caption).frame(maxWidth: .infinity, minHeight: 36)
                            .background { HabitTileView(day: day, accent: accent).accessibilityHidden(true) }
                            .opacity(day.isInMonth ? 1 : 0.2)
                            .accessibilityLabel(day.accessibilityLabel)
                    }
        }
    }
}
