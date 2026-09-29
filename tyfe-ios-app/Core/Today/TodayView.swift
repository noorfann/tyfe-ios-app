import SwiftUI
import SwiftfulUI

struct TodayDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct TodayView: View {

    @State private var presenter: TodayPresenter
    let delegate: TodayDelegate
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(presenter: TodayPresenter, delegate: TodayDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    if presenter.hasPlan {
                        plannedContent
                    } else {
                        dayNavigator
                        if presenter.isViewingToday {
                            projectTabs
                            emptyContent
                        } else {
                            TodayHistoricalEmptyView(completedSessionCount: presenter.completedSessionUnitCount)
                        }
                    }
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)

            if presenter.isViewingToday {
                floatingAddButton
            }
            devSettingsButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tyfeBottomSheet(
            isPresented: $presenter.isAddActivitySheetPresented,
            title: "Add to Today"
        ) {
            TodayAddActivitySheet(
                initialSessionCount: presenter.addActivitySessionCount,
                projects: presenter.projects,
                initialProjectId: presenter.addActivityProjectId,
                onSave: presenter.saveActivity
            )
        }
        .tyfeBottomSheet(
            isPresented: $presenter.isActivityDetailSheetPresented,
            title: "Activity Details"
        ) {
            if let activity = presenter.editingActivity,
               let item = presenter.editingPlanItem {
                TodayActivityDetailSheet(
                    activity: activity,
                    initialSessionCount: item.plannedSessionCount,
                    completedUnitCount: presenter.completedCount(for: item),
                    checklistItems: presenter.checklistItems(for: item),
                    tickedItemIds: presenter.tickedItemIds,
                    canConvertToChecklist: presenter.canConvertEditingActivity(to: .checklist),
                    canConvertToSession: presenter.canConvertEditingActivity(to: .session),
                    projects: presenter.projects,
                    onSave: presenter.saveActivityEdits,
                    onRemove: presenter.removeEditingActivityFromToday
                )
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: presenter.isAddActivitySheetPresented) { _, isPresented in
            guard !isPresented else { return }
            presenter.onAddActivitySheetDismissed()
        }
        .onChange(of: presenter.isActivityDetailSheetPresented) { _, isPresented in
            guard !isPresented else { return }
            presenter.onActivityDetailSheetDismissed()
        }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Text("tyfe")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: presenter.isDarkAppearance ? "moon.stars.fill" : "sun.max.fill")
                .font(.subheadline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.onAccent)
                .frame(width: 40, height: 40)
                .background(TyfeEditorialPalette.teal)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: TyfeRadius.control)
                        .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
                }
                .asButton(.press) {
                    presenter.onToggleAppearancePressed()
                }
                .accessibilityLabel("Appearance")
                .accessibilityValue(presenter.isDarkAppearance ? "Dark" : "Light")
                .accessibilityHint("Switches between light and dark appearance")

            HStack(spacing: 5) {
                Image(systemName: "flame.fill")
                    .accessibilityHidden(true)
                Text(String(presenter.currentStreakCount))
                    .monospacedDigit()
            }
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.onAccent)
                .padding(.horizontal, TyfeSpacing.small)
                .frame(minWidth: 40, minHeight: 40)
                .background(TyfeEditorialPalette.saffron)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: TyfeRadius.control)
                        .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
                }
                .asButton(.press) {
                    presenter.onStreakPressed()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Current streak")
                .accessibilityValue("\(presenter.currentStreakCount) days")
                .accessibilityHint("Opens streak details")
                .accessibilityIdentifier("today-streak-button")
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    TyfeMotifView(kind: .tile)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accessibilityHidden(true)

                    Text(presenter.greeting)
                        .font(TyfeTypography.display)
                        .tracking(-1.6)

                    Text(presenter.selectedProjectId == nil
                        ? "What would you like to make room for today?"
                        : "What would you like to make room for in \(presenter.selectedProjectTitle) today?"
                    )
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    TyfeActionButtonView(
                        title: presenter.selectedProjectId == nil
                            ? "Add your first Activity"
                            : "Add Activity to \(presenter.selectedProjectTitle)",
                        systemImage: "plus",
                        onTap: presenter.onCreatePlanPressed
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var plannedContent: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.section) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                Text(presenter.isViewingToday ? presenter.greeting : "Day overview")
                    .font(TyfeTypography.displayCompact)
                    .tracking(-0.8)

                Text(presenter.isViewingToday ? "Choose what to focus on next." : "Your recorded plan for this day.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }

            if presenter.dailyPlan != nil {
                HStack(spacing: TyfeSpacing.control) {
                    if presenter.showsTasksMetric {
                        TyfeMetricCardView(
                            title: "Tasks",
                            value: presenter.taskProgressLabel,
                            systemImage: "checklist",
                            accent: TyfeEditorialPalette.saffron
                        )
                    }
                    sessionsMetric
                }
            }

            dayNavigator
            projectTabs
            planDeck

            if !presenter.hasUnfinishedPlan, presenter.planHasPlannedUnits {
                TyfeSurfaceView(role: .paper) {
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TyfeEditorialPalette.success)
                        Text(presenter.isViewingToday
                             ? "Today’s plan is complete."
                             : "The recorded plan was completed.")
                            .font(TyfeTypography.interfaceStrong)
                    }
                }
            }
        }
    }

    private var projectTabs: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("SPACES")
                .font(TyfeTypography.eyebrow)
                .tracking(1.1)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .accessibilityAddTraits(.isHeader)

            TodayProjectDeckTabsView(
                projects: presenter.projects,
                showsUnassigned: presenter.hasUnassignedPlannedActivities,
                selectedProjectId: presenter.selectedProjectId,
                isManagementEnabled: presenter.isViewingToday,
                onSelect: presenter.selectProject,
                onManage: presenter.onProjectManagementPressed
            )
        }
    }

    private var dayNavigator: some View {
        TodayDateNavigatorView(
            title: presenter.selectedDayTitle,
            dateLabel: presenter.selectedDayDateLabel,
            canViewPreviousDay: presenter.canViewPreviousDay,
            canViewNextDay: presenter.canViewNextDay,
            onPreviousDay: presenter.onPreviousDayPressed,
            onNextDay: presenter.onNextDayPressed
        )
    }

    private var planDeck: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            if !presenter.isViewingToday {
                Text("ACTIVITIES")
                    .font(TyfeTypography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }

            if presenter.deckPlanItems.isEmpty {
                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        Text("No planned Activities in \(presenter.selectedProjectTitle).")
                            .font(TyfeTypography.interfaceStrong)
                        if presenter.isViewingToday {
                            Text("Add an Activity to this deck to get started.")
                                .font(TyfeTypography.interface)
                                .foregroundStyle(TyfeEditorialPalette.muted)
                        }
                    }
                }
            } else {
                ZStack(alignment: .top) {
                    TodayActivityDeckView(
                        planItems: presenter.deckPlanItems,
                        activities: presenter.activities,
                        completedUnitCounts: presenter.completedUnitCounts,
                        checklistItemsByActivity: presenter.checklistItemsByActivity,
                        tickedItemIds: presenter.tickedItemIds,
                        selectedPlanItemId: presenter.selectedPlanItemId,
                        nextPlanItemId: presenter.isViewingToday ? presenter.nextDeckPlanItem?.id : nil,
                        isRewardInProgress: presenter.isRewardInProgress,
                        isReadOnly: !presenter.isViewingToday,
                        onStart: { _ in presenter.onStartFocusPressed() },
                        onEdit: { presenter.onEditActivityPressed($0) },
                        onToggleChecklistItem: { presenter.onChecklistItemToggled($0) },
                        onNext: presenter.selectNextPlanItem,
                        onPrevious: presenter.selectPreviousPlanItem
                    )
                    .id("\(presenter.selectedLocalDay.id)-\(presenter.selectedProjectId ?? "unassigned")")

                    if presenter.isViewingToday && presenter.isDeckSwipeCoachmarkPresented {
                        deckSwipeCoachmark
                    }
                }
                .animation(
                    reduceMotion ? nil : TyfeMotion.normalAnimation,
                    value: presenter.isDeckSwipeCoachmarkPresented
                )
            }
        }
    }

    private var deckSwipeCoachmark: some View {
        TyfeCoachmarkView(
            title: "More activities",
            message: "Your activity cards stack here. Swipe to move between them.",
            systemImage: "rectangle.stack.fill",
            onDismiss: presenter.dismissDeckSwipeCoachmark
        )
        .padding(.horizontal, TyfeSpacing.control)
        .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .top)))
        .task {
            try? await Task.sleep(for: .seconds(4))
            presenter.dismissDeckSwipeCoachmark()
        }
        .accessibilitySortPriority(1)
    }

    private var floatingAddButton: some View {
        Image(systemName: "plus")
            .font(.title2.weight(.black))
            .foregroundStyle(TyfeEditorialPalette.onAccent)
            .frame(width: 58, height: 58)
            .background(TyfeEditorialPalette.focus)
            .clipShape(Circle())
            .overlay {
                Circle()
                    .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
            }
            .shadow(
                color: TyfeEditorialPalette.shadow.opacity(TyfeShadow.opacity),
                radius: TyfeShadow.radius,
                x: TyfeShadow.offset.width,
                y: TyfeShadow.offset.height
            )
            .asButton(.press) {
                presenter.onAddActivityPressed()
            }
            .accessibilityLabel("Add Activity to Today")
            .padding(.trailing, TyfeSpacing.control)
            .padding(.bottom, TyfeSpacing.control)
    }

    private var sessionsMetric: some View {
        TyfeMetricCardView(
            title: "Sessions",
            value: presenter.sessionProgressLabel,
            systemImage: "list.bullet.rectangle",
            accent: TyfeEditorialPalette.teal
        )
    }

    private var devSettingsButton: some View {
        #if DEV || MOCK
        Text("DEV")
            .font(TyfeTypography.caption)
            .foregroundStyle(TyfeEditorialPalette.onDark)
            .padding(.horizontal, TyfeSpacing.small)
            .frame(minHeight: 32)
            .background(TyfeEditorialPalette.navy)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(TyfeEditorialPalette.controlBorder, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                presenter.onDevSettingsPressed()
            }
            .padding(.leading, TyfeSpacing.control)
            .padding(.bottom, TyfeSpacing.small)
        #else
        EmptyView()
        #endif
    }
}

#Preview("Today — empty") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.todayView(router: router, delegate: TodayDelegate())
    }
}

#Preview("Today — planned") {
    let container = DevPreview.shared.container()
    let manager = container.resolve(TodayManager.self)!
    _ = manager.acceptDailyPlan(
        intendedSessionCount: 16,
        activityIds: [ActivityModel.mock.activityId],
        timeBlocks: nil
    )
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.todayView(router: router, delegate: TodayDelegate())
    }
}

extension CoreBuilder {
    func todayView(router: AnyRouter, delegate: TodayDelegate) -> some View {
        TodayView(
            presenter: TodayPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showTodayView(delegate: TodayDelegate = TodayDelegate()) {
        router.showScreen(.push) { router in
            builder.todayView(router: router, delegate: delegate)
        }
    }
}
