import SwiftUI
import SwiftfulUI

struct TodayDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct TodayView: View {

    @State private var presenter: TodayPresenter
    let delegate: TodayDelegate

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
                        emptyContent
                    }
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, 96)
            }
            .scrollIndicators(.hidden)

            floatingAddButton
            devSettingsButton
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $presenter.isAddActivitySheetPresented) {
            TodayAddActivitySheet(
                initialSessionCount: presenter.addActivitySessionCount,
                onSave: presenter.saveActivity
            )
            .presentationDetents([.fraction(0.8)])
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Text("tyfe")
                .font(TyfeTypography.displayCompact)
                .tracking(-1.2)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Today")
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.muted)

            Image(systemName: presenter.isDarkAppearance ? "sun.max.fill" : "moon.stars.fill")
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

            Text("T")
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.onAccent)
                .frame(width: 40, height: 40)
                .background(TyfeEditorialPalette.teal)
                .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
                .overlay {
                    RoundedRectangle(cornerRadius: TyfeRadius.control)
                        .stroke(TyfeEditorialPalette.onAccent, lineWidth: TyfeStroke.standard)
                }
                .accessibilityLabel("Profile")
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
                Text(presenter.greeting)
                    .font(TyfeTypography.displayCompact)
                    .tracking(-0.8)

                Text("Choose what to focus on next.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }

            if presenter.dailyPlan != nil {
                HStack(spacing: TyfeSpacing.control) {
                    TyfeMetricCardView(
                        title: "Credits",
                        value: String(presenter.rewardCredits),
                        detail: "Reward Credits",
                        systemImage: "circle.fill",
                        accent: TyfeEditorialPalette.saffron
                    )
                    TyfeMetricCardView(
                        title: "Today",
                        value: presenter.planProgressLabel,
                        detail: "Daily progress",
                        systemImage: "checkmark.circle.fill",
                        accent: TyfeEditorialPalette.teal
                    )
                }
            }

            if let activeSession = presenter.activeFocusSession,
               let activity = presenter.activities.first(where: { $0.activityId == activeSession.activityId }) {
                TyfeSurfaceView(role: .focusChamber) {
                    HStack(spacing: TyfeSpacing.control) {
                        Image(systemName: activeSession.state.symbolName)
                            .font(.title2.weight(.black))
                            .foregroundStyle(TyfeEditorialPalette.focus)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(activeSession.state == .ready ? "Focus is ready" : "Focus in progress")
                                .font(TyfeTypography.interfaceStrong)
                                .foregroundStyle(TyfeEditorialPalette.onDark)
                            Text(activity.name)
                                .font(TyfeTypography.interface)
                                .foregroundStyle(TyfeEditorialPalette.onDark.opacity(0.72))
                        }

                    }
                    .contentShape(Rectangle())
                    .asButton(.press) {
                        presenter.onResumeActiveFocusPressed()
                    }
                    .accessibilityLabel("Resume focus session for \(activity.name)")
                }
            }

            planDeck

            if !presenter.hasUnfinishedPlan {
                TyfeSurfaceView(role: .paper) {
                    HStack(spacing: TyfeSpacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(TyfeEditorialPalette.success)
                        Text("Today’s planned sessions are complete.")
                            .font(TyfeTypography.interfaceStrong)
                    }
                }
            }
        }
    }

    private var planDeck: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("TODAY’S ACTIVITIES")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)

            TodayActivityDeckView(
                planItems: presenter.planItems,
                activities: presenter.activities,
                completedSessionCounts: presenter.completedSessionCounts,
                selectedPlanItemId: presenter.selectedPlanItemId,
                nextPlanItemId: presenter.nextPlanItem?.id,
                canDecrement: { presenter.canDecrement($0) },
                onStart: { presenter.onStartFocusPressed(for: $0) },
                onIncrement: { presenter.increment($0) },
                onDecrement: { presenter.decrement($0) },
                onRemove: { presenter.remove($0) },
                onNext: presenter.selectNextPlanItem,
                onPrevious: presenter.selectPreviousPlanItem
            )
        }
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
                    .stroke(TyfeEditorialPalette.onDark, lineWidth: TyfeStroke.hairline)
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
    let canDecrement: (DailyPlanItemModel) -> Bool
    let onStart: (DailyPlanItemModel) -> Void
    let onIncrement: (DailyPlanItemModel) -> Void
    let onDecrement: (DailyPlanItemModel) -> Void
    let onRemove: (DailyPlanItemModel) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var dragOffset: CGFloat = 0
    @ScaledMetric(relativeTo: .body) private var deckHeight: CGFloat = 284
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
            .frame(height: deckHeight)
            .contentShape(Rectangle())
            .gesture(deckGesture)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Today activities")
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
            canDecrement: canDecrement(card.item),
            onStart: { onStart(card.item) },
            onIncrement: { onIncrement(card.item) },
            onDecrement: { onDecrement(card.item) },
            onRemove: { onRemove(card.item) }
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
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
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
    let canDecrement: Bool
    let onStart: () -> Void
    let onIncrement: () -> Void
    let onDecrement: () -> Void
    let onRemove: () -> Void

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

                HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                    Text("\(completedCount) of \(item.plannedSessionCount) sessions")
                        .font(TyfeTypography.interfaceStrong)
                    Text("· \(item.plannedSessionCount * FocusSessionModel.durationMinutes) min focus")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(isComplete ? TyfeEditorialPalette.disabledInk : TyfeEditorialPalette.muted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                HStack(spacing: TyfeSpacing.small) {
                    stepperButton(
                        systemImage: "minus",
                        label: "Fewer " + activity.name + " sessions",
                        isEnabled: canDecrement,
                        action: onDecrement
                    )

                    Text("Plan count")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                        .frame(maxWidth: .infinity)

                    stepperButton(
                        systemImage: "plus",
                        label: "More " + activity.name + " sessions",
                        isEnabled: true,
                        action: onIncrement
                    )

                    if completedCount == 0 {
                        Image(systemName: "trash")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(TyfeEditorialPalette.error)
                            .frame(width: 44, height: 44)
                            .asButton(.press, action: onRemove)
                            .accessibilityLabel("Remove " + activity.name + " from Today")
                    }
                }

                TyfeActionButtonView(
                    title: isComplete ? "Completed" : "Start " + activity.name,
                    systemImage: isComplete ? "checkmark" : "play.fill",
                    isEnabled: !isComplete,
                    onTap: onStart
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(activity.name), \(completedCount) of \(item.plannedSessionCount) sessions")
    }

    private func stepperButton(
        systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.black))
            .foregroundStyle(isEnabled ? TyfeEditorialPalette.ink : TyfeEditorialPalette.disabledInk)
            .frame(width: 44, height: 44)
            .background(isEnabled ? TyfeEditorialPalette.canvas : TyfeEditorialPalette.disabledFill)
            .clipShape(RoundedRectangle(cornerRadius: TyfeRadius.control))
            .overlay {
                RoundedRectangle(cornerRadius: TyfeRadius.control)
                    .stroke(TyfeEditorialPalette.ink, lineWidth: TyfeStroke.hairline)
            }
            .asButton(.press) {
                guard isEnabled else { return }
                action()
            }
            .disabled(!isEnabled)
            .accessibilityLabel(label)
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
