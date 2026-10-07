import SwiftUI
import SwiftfulUI

struct TodayHabitView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let presenter: TodayEffortPresenter
    let projectId: String?

    var body: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
            TyfeMetricCardView(
                title: "Habits today", value: presenter.habitProgress(in: projectId),
                systemImage: "leaf.fill", accent: TyfeEditorialPalette.teal
            )
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                    Text(presenter.showsArchivedHabits ? "Show active Habits" : "Archived Habits")
                        .font(TyfeTypography.caption).frame(minHeight: 44)
                        .asButton(.press, action: presenter.toggleArchivedHabits)
                    periodSelector
                }
                habitContent
            }
        }
        .accessibilityIdentifier("today-habit-page")
    }

    @ViewBuilder private var habitContent: some View {
        if presenter.habits(in: projectId).isEmpty {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                    Text(presenter.showsArchivedHabits ? "No archived Habits." : "Small things, often.")
                        .font(TyfeTypography.displayCompact)
                    Text("One check for each scheduled day. Your history grows one tile at a time.")
                        .font(TyfeTypography.interface).foregroundStyle(TyfeEditorialPalette.muted)
                    TyfeActionButtonView(title: "Add Habit", systemImage: "plus") { presenter.addHabit(in: projectId) }
                }
            }
        } else {
            LazyVStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                ForEach(presenter.habits(in: projectId)) { habit in
                    if let history = presenter.habitCardHistories[habit.id] {
                        HabitCardView(
                            habit: habit, occurrence: presenter.occurrence(for: habit.id),
                            streak: presenter.streak(for: habit.id), history: history,
                            scheduleLabel: habit.revision(on: presenter.today)?.schedule.displaySummary ?? "Archived",
                            onCheck: { presenter.toggleHabit(habit) }, onSkip: { presenter.toggleSkip(habit) },
                            onDetail: { presenter.showHabit(habit) }
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder private var periodSelector: some View {
        @Bindable var periodPresenter = presenter
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: TyfeSpacing.relatedGap) {
                    ForEach(HabitViewPeriod.allCases) { period in
                        Text(period.title)
                            .font(TyfeTypography.interfaceStrong).frame(maxWidth: .infinity, minHeight: 44)
                            .background(presenter.habitViewPeriod == period ? TyfeEditorialPalette.focus : TyfeEditorialPalette.paper)
                            .foregroundStyle(presenter.habitViewPeriod == period ? TyfeEditorialPalette.onAccent : TyfeEditorialPalette.ink)
                            .clipShape(.rect(cornerRadius: TyfeRadius.control))
                            .asButton(.press) { presenter.selectHabitViewPeriod(period) }
                            .accessibilityAddTraits(presenter.habitViewPeriod == period ? .isSelected : [])
                            .accessibilityLabel("\(period.title) habit view")
                    }
                }
            } else {
                Picker("Habit view period", selection: $periodPresenter.habitPeriodSelection) {
                    ForEach(HabitViewPeriod.allCases) { period in Text(period.title).tag(period) }
                }
                .pickerStyle(.segmented)
            }
            if !presenter.habits(in: projectId).isEmpty {
                Text("Filled: completed · Outline: missed · Dash: skipped · Faint: unscheduled or future.")
                    .font(TyfeTypography.caption).foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
        .accessibilityIdentifier("habit-period-selector")
    }
}

@MainActor
private func habitSpacingPreview(router: AnyRouter, period: HabitViewPeriod, archived: Bool, empty: Bool) -> TodayHabitView {
    var snapshot = LocalAppSnapshot.mock
    if !empty {
        snapshot.effort.habits = [
            HabitCardPreviewData.card(period: period, isArchived: archived).habit,
            HabitCardPreviewData.card(period: period, isNew: true, isArchived: archived).habit
        ]
    }
    let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false), snapshotOverride: snapshot)
    let interactor = CoreInteractor(container: dependencies.container)
    dependencies.container.resolve(TodayManager.self)?.setHabitViewPeriod(period)
    let builder = CoreBuilder(interactor: interactor)
    let presenter = TodayEffortPresenter(interactor: interactor, router: CoreRouter(router: router, builder: builder))
    presenter.reload()
    presenter.showsArchivedHabits = archived
    return TodayHabitView(presenter: presenter, projectId: nil)
}

#Preview("Habit spacing · active and archived · all periods") {
    RouterView { router in
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.majorGap) {
                ForEach(HabitViewPeriod.allCases) { period in
                    habitSpacingPreview(router: router, period: period, archived: false, empty: false)
                    habitSpacingPreview(router: router, period: period, archived: true, empty: false)
                }
            }
            .padding(TyfeSpacing.screenInset)
        }
    }
}

#Preview("Habit spacing · empty active and archived · all periods") {
    RouterView { router in
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.majorGap) {
                ForEach(HabitViewPeriod.allCases) { period in
                    habitSpacingPreview(router: router, period: period, archived: false, empty: true)
                    habitSpacingPreview(router: router, period: period, archived: true, empty: true)
                }
            }
            .padding(TyfeSpacing.screenInset)
        }
    }
}

#Preview("Habit spacing · accessibility · all periods") {
    RouterView { router in
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.majorGap) {
                ForEach(HabitViewPeriod.allCases) { period in
                    habitSpacingPreview(router: router, period: period, archived: false, empty: false)
                    habitSpacingPreview(router: router, period: period, archived: true, empty: false)
                    habitSpacingPreview(router: router, period: period, archived: false, empty: true)
                    habitSpacingPreview(router: router, period: period, archived: true, empty: true)
                }
            }
            .padding(TyfeSpacing.screenInset)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
