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
                            emptyContent
                        } else {
                            TodayHistoricalEmptyView(completedSessionCount: presenter.completedSessionCount)
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
                    completedSessionCount: presenter.completedCount(for: item),
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

                    Text("What would you like to make room for today?")
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    TyfeActionButtonView(
                        title: "Add your first Activity",
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
                if presenter.isViewingToday {
                    HStack(spacing: TyfeSpacing.control) {
                        TyfeMetricCardView(
                            title: "Credits",
                            value: String(presenter.rewardCredits),
                            systemImage: "creditcard.rewards",
                            accent: TyfeEditorialPalette.saffron
                        )
                        sessionsMetric
                    }
                } else {
                    sessionsMetric
                }
            }

            dayNavigator
            planDeck

            if !presenter.hasUnfinishedPlan {
                TyfeSurfaceView(role: .paper) {
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TyfeEditorialPalette.success)
                        Text(presenter.isViewingToday
                             ? "Today’s planned sessions are complete."
                             : "Planned sessions were completed.")
                            .font(TyfeTypography.interfaceStrong)
                    }
                }
            }
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
            Text(presenter.isViewingToday ? "TODAY’S ACTIVITIES" : "ACTIVITIES")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)

            ZStack(alignment: .top) {
                TodayActivityDeckView(
                    planItems: presenter.planItems,
                    activities: presenter.activities,
                    completedSessionCounts: presenter.completedSessionCounts,
                    selectedPlanItemId: presenter.selectedPlanItemId,
                    nextPlanItemId: presenter.isViewingToday ? presenter.nextPlanItem?.id : nil,
                    isRewardInProgress: presenter.isRewardInProgress,
                    isReadOnly: !presenter.isViewingToday,
                    onStart: { _ in presenter.onStartFocusPressed() },
                    onEdit: { presenter.onEditActivityPressed($0) },
                    onNext: presenter.selectNextPlanItem,
                    onPrevious: presenter.selectPreviousPlanItem
                )

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
            value: presenter.planProgressLabel,
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

struct TodayActivityDeckView: View {

    let planItems: [DailyPlanItemModel]
    let activities: [ActivityModel]
    let completedSessionCounts: [String: Int]
    let selectedPlanItemId: String?
    let nextPlanItemId: String?
    let isRewardInProgress: Bool
    let isReadOnly: Bool
    let onStart: (DailyPlanItemModel) -> Void
    let onEdit: (DailyPlanItemModel) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDeckDragging = false
    @GestureState private var isDeckGestureActive = false
    @ScaledMetric(relativeTo: .body) private var deckHeight: CGFloat = 248
    @ScaledMetric(relativeTo: .body) private var readOnlyDeckHeight: CGFloat = 196
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var deckAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)
    }

    private var selectedIndex: Int? {
        guard let selectedPlanItemId else { return nil }
        return planItems.firstIndex { $0.id == selectedPlanItemId }
    }

    private var visibleCards: [DeckCard] {
        guard !planItems.isEmpty, let selectedIndex else { return [] }
        let visibleCardCount = min(3, planItems.count)

        return (0..<visibleCardCount).compactMap { depth in
            let item = planItems[(selectedIndex + depth) % planItems.count]
            guard let activity = activities.first(where: { $0.activityId == item.activityId }) else {
                return nil
            }
            return DeckCard(
                item: item,
                activity: activity,
                position: depth
            )
        }
    }

    var body: some View {
        if let selectedIndex {
            ZStack {
                ForEach(visibleCards.reversed()) { card in
                    cardView(card)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: isReadOnly ? readOnlyDeckHeight : deckHeight)
            .contentShape(Rectangle())
            .simultaneousGesture(deckGesture)
            .onChange(of: isDeckGestureActive) { _, isActive in
                guard !isActive else { return }
                isDeckDragging = false
                guard dragOffset != 0 else { return }
                withAnimation(deckAnimation) {
                    dragOffset = 0
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(isReadOnly ? "Historical activities" : "Today activities")
            .accessibilityValue("Activity \(selectedIndex + 1) of \(planItems.count)")
            .accessibilityHint("Swipe left or right to switch activities.")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    onNext()
                case .decrement:
                    onPrevious()
                @unknown default:
                    break
                }
            }
        }
    }

    private func cardView(_ card: DeckCard) -> some View {
        let depth = card.position
        let completedCount = completedSessionCounts[card.item.activityId, default: 0]

        return TodayPlanCardView(
            activity: card.activity,
            item: card.item,
            completedCount: completedCount,
            isNext: nextPlanItemId == card.item.id,
            isRewardInProgress: isRewardInProgress,
            isReadOnly: isReadOnly,
            isDeckDragging: isDeckDragging,
            onStart: { onStart(card.item) },
            onEdit: { onEdit(card.item) }
        )
        .scaleEffect(1 - (CGFloat(depth) * 0.035))
        .offset(
            x: depth == 0 ? dragOffset : 0,
            y: CGFloat(depth) * 12
        )
        .opacity(1 - (Double(depth) * 0.12))
        .zIndex(Double(visibleCards.count - depth))
        .allowsHitTesting(depth == 0)
        .animation(deckAnimation, value: selectedPlanItemId)
    }

    private var deckGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isDeckGestureActive) { _, state, _ in
                state = true
            }
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                isDeckDragging = true
                dragOffset = value.translation.width
            }
            .onEnded { value in
                let translation = value.translation.width
                let isHorizontal = abs(translation) > abs(value.translation.height)
                let passedThreshold = abs(translation) > 80

                guard isHorizontal, passedThreshold else {
                    withAnimation(deckAnimation) {
                        dragOffset = 0
                    }
                    return
                }

                withAnimation(deckAnimation) {
                    if translation < 0 {
                        onNext()
                    } else {
                        onPrevious()
                    }
                    dragOffset = 0
                }
            }
    }

    private struct DeckCard: Identifiable {
        let item: DailyPlanItemModel
        let activity: ActivityModel
        let position: Int

        var id: String {
            item.id
        }
    }
}

struct TodayPlanCardView: View {

    let activity: ActivityModel
    let item: DailyPlanItemModel
    let completedCount: Int
    let isNext: Bool
    let isRewardInProgress: Bool
    let isReadOnly: Bool
    let isDeckDragging: Bool
    let onStart: () -> Void
    let onEdit: () -> Void

    private var isComplete: Bool {
        completedCount >= item.plannedSessionCount
    }

    var body: some View {
        TyfeSurfaceView(role: isComplete ? .disabled : .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .top, spacing: TyfeSpacing.small) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.unit) {
                        Text(isNext && !isComplete ? "NEXT UP" : "ACTIVITY")
                            .font(TyfeTypography.eyebrow)
                            .tracking(1.1)
                            .foregroundStyle(isComplete ? TyfeEditorialPalette.disabledInk : TyfeEditorialPalette.muted)

                        Text(activity.name)
                            .font(TyfeTypography.displayCompact)
                            .tracking(-0.8)
                            .lineLimit(2)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if isComplete {
                        Label("Complete", systemImage: "checkmark.circle.fill")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.disabledInk)
                    } else if completedCount > 0 {
                        Text("In progress")
                            .font(TyfeTypography.caption)
                            .foregroundStyle(TyfeEditorialPalette.muted)
                    }
                }

                if isReadOnly {
                    Text(progressLabel)
                        .font(TyfeTypography.interfaceStrong)
                } else {
                    HStack(spacing: TyfeSpacing.small) {
                        Text(progressLabel)
                            .font(TyfeTypography.interfaceStrong)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Label("Edit", systemImage: "pencil")
                            .font(TyfeTypography.interfaceStrong)
                            .foregroundStyle(TyfeEditorialPalette.ink)
                            .padding(.horizontal, TyfeSpacing.control)
                            .frame(minHeight: 44)
                            .background(TyfeEditorialPalette.canvas)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(
                                        TyfeEditorialPalette.controlBorder,
                                        lineWidth: TyfeStroke.hairline
                                    )
                            }
                            .contentShape(Capsule())
                            .asButton(.press, action: onEdit)
                            .disabled(isDeckDragging)
                            .accessibilityLabel("Edit " + activity.name)
                    }

                    TyfeActionButtonView(
                        title: startButtonTitle,
                        systemImage: startButtonSystemImage,
                        isEnabled: !isComplete && !isRewardInProgress,
                        onTap: onStart
                    )
                    .disabled(isDeckDragging)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var startButtonTitle: String {
        if isComplete { return "Completed" }
        return isRewardInProgress ? "Reward in progress" : "Start"
    }

    private var startButtonSystemImage: String {
        if isComplete { return "checkmark" }
        return isRewardInProgress ? "clock.fill" : "play.fill"
    }

    private var progressLabel: String {
        "\(completedCount) of \(item.plannedSessionCount) sessions"
    }

    private var accessibilityLabel: String {
        let progress = "\(activity.name), \(progressLabel)"
        guard isRewardInProgress && !isComplete else { return progress }
        return progress + ". Focus unavailable while Reward is in progress."
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
