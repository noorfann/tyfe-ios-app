import SwiftUI
import SwiftfulUI

struct TodayActivityDeckView: View {

    let planItems: [DailyPlanItemModel]
    let activities: [ActivityModel]
    let completedUnitCounts: [String: Int]
    let checklistItemsByActivity: [String: [ChecklistItemModel]]
    let tickedItemIds: Set<String>
    let selectedPlanItemId: String?
    let nextPlanItemId: String?
    let isRewardInProgress: Bool
    let isReadOnly: Bool
    let onStart: (DailyPlanItemModel) -> Void
    let onEdit: (DailyPlanItemModel) -> Void
    let onToggleChecklistItem: (ChecklistItemModel) -> Void
    let onNext: () -> Void
    let onPrevious: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var isDeckDragging = false
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var deckAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)
    }

    private func entranceAnimation(depth: Int) -> Animation? {
        guard !reduceMotion else { return nil }
        return .spring(response: 0.38, dampingFraction: 0.78)
            .delay(Double(depth) * 0.06)
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
            VStack(spacing: TyfeSpacing.sectionGap) {
                ZStack {
                    ForEach(visibleCards.reversed()) { card in
                        cardView(card)
                    }
                }
                .frame(maxWidth: .infinity)
                .animation(deckAnimation, value: selectedIndex)
                .contentShape(Rectangle())
                .gesture(
                    DeckSwipeGesture(
                        onBegan: {
                            isDeckDragging = true
                        },
                        onChanged: { translation in
                            dragOffset = translation
                        },
                        onEnded: { translation, velocity in
                            endDeckSwipe(translation: translation, velocity: velocity)
                        },
                        onCancelled: {
                            isDeckDragging = false
                            withAnimation(deckAnimation) {
                                dragOffset = 0
                            }
                        }
                    )
                )
                .onAppear { hasAppeared = true }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(isReadOnly ? "Historical activities" : "Activities")
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

                HStack(spacing: TyfeSpacing.relatedGap) {
                    ForEach(planItems.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex
                                  ? TyfeEditorialPalette.teal
                                  : TyfeEditorialPalette.muted.opacity(0.45))
                            .frame(width: 8, height: 8)
                    }
                }
                .frame(minHeight: 24)
                .accessibilityHidden(true)
                .animation(deckAnimation, value: selectedIndex)
            }
        }
    }

    private func cardView(_ card: DeckCard) -> some View {
        let depth = card.position
        let completedCount = completedUnitCounts[card.item.activityId, default: 0]

        return TodayPlanCardView(
            activity: card.activity,
            item: card.item,
            completedCount: completedCount,
            checklistItems: checklistItemsByActivity[card.item.activityId] ?? [],
            tickedItemIds: tickedItemIds,
            isNext: nextPlanItemId == card.item.id,
            isRewardInProgress: isRewardInProgress,
            isReadOnly: isReadOnly,
            isDeckDragging: isDeckDragging,
            onStart: { onStart(card.item) },
            onEdit: { onEdit(card.item) },
            onToggleChecklistItem: onToggleChecklistItem
        )
        .scaleEffect((1 - (CGFloat(depth) * 0.035)) * (hasAppeared ? 1 : 0.94))
        .offset(
            x: depth == 0 ? dragOffset : 0,
            y: (CGFloat(depth) * 12) + (hasAppeared ? 0 : -32)
        )
        .opacity((1 - (Double(depth) * 0.12)) * (hasAppeared ? 1 : 0))
        .zIndex(Double(visibleCards.count - depth))
        .allowsHitTesting(depth == 0)
        .animation(deckAnimation, value: selectedPlanItemId)
        .animation(entranceAnimation(depth: depth), value: hasAppeared)
    }

    private func endDeckSwipe(translation: CGFloat, velocity: CGFloat) {
        isDeckDragging = false

        let projectedTranslation = translation + (velocity * 0.25)
        guard abs(projectedTranslation) > 80 else {
            withAnimation(deckAnimation) {
                dragOffset = 0
            }
            return
        }

        withAnimation(deckAnimation) {
            if projectedTranslation < 0 {
                onNext()
            } else {
                onPrevious()
            }
            dragOffset = 0
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
    private static let scrollIndicatorInset: CGFloat = 2

    let activity: ActivityModel
    let item: DailyPlanItemModel
    let completedCount: Int
    let checklistItems: [ChecklistItemModel]
    let tickedItemIds: Set<String>
    let isNext: Bool
    let isRewardInProgress: Bool
    let isReadOnly: Bool
    let isDeckDragging: Bool
    let onStart: () -> Void
    let onEdit: () -> Void
    let onToggleChecklistItem: (ChecklistItemModel) -> Void

    @State private var checklistScrollOffset: CGFloat = 0
    @State private var checklistContentHeight: CGFloat = 0
    @State private var checklistViewportHeight: CGFloat = 0

    private var isChecklist: Bool {
        activity.type == .checklist
    }

    private var isComplete: Bool {
        item.plannedSessionCount > 0 && completedCount >= item.plannedSessionCount
    }

    var body: some View {
        TyfeSurfaceView(role: isComplete ? .disabled : .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                cardHeader

                if isChecklist {
                    checklistContent
                } else {
                    sessionContent
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: TyfeSpacing.relatedGap) {
            VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
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
    }

    private var sessionContent: some View {
        Group {
            if isReadOnly {
                Text(progressLabel)
                    .font(TyfeTypography.interfaceStrong)
            } else {
                HStack(spacing: TyfeSpacing.relatedGap) {
                    Text(progressLabel)
                        .font(TyfeTypography.interfaceStrong)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    editButton
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

    private var checklistContent: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            HStack(spacing: TyfeSpacing.relatedGap) {
                Text(progressLabel)
                    .font(TyfeTypography.interfaceStrong)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !isReadOnly {
                    editButton
                }
            }

            if checklistItems.isEmpty {
                Text("No items yet. Tap Edit to add items.")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
                        ForEach(checklistItems) { checklistItem in
                            checklistRow(checklistItem)
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        checklistContentHeight = height
                    }
                }
                .frame(maxHeight: 140)
                .scrollIndicators(.hidden)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    checklistViewportHeight = height
                }
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                } action: { _, offset in
                    checklistScrollOffset = offset
                }
                .overlay(alignment: .topTrailing) {
                    checklistScrollIndicator
                }
            }
        }
    }

    private var isChecklistScrollable: Bool {
        checklistContentHeight > checklistViewportHeight + 1
    }

    private var checklistThumbHeight: CGFloat {
        guard isChecklistScrollable, checklistContentHeight > 0 else { return 0 }
        let visibleRatio = checklistViewportHeight / checklistContentHeight
        return max(checklistViewportHeight * visibleRatio, 24)
    }

    private var checklistThumbOffset: CGFloat {
        let maxOffset = checklistContentHeight - checklistViewportHeight
        guard maxOffset > 0 else { return 0 }
        let progress = min(max(checklistScrollOffset / maxOffset, 0), 1)
        return progress * max(checklistViewportHeight - checklistThumbHeight, 0)
    }

    private var checklistScrollIndicator: some View {
        Group {
            if isChecklistScrollable {
                Capsule()
                    .fill(TyfeEditorialPalette.focus)
                    .frame(width: 3, height: checklistThumbHeight)
                    .padding(.top, checklistThumbOffset)
                    .padding(.trailing, Self.scrollIndicatorInset)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func checklistRow(_ checklistItem: ChecklistItemModel) -> some View {
        let isTicked = tickedItemIds.contains(checklistItem.itemId)
        return HStack(spacing: TyfeSpacing.relatedGap) {
            Image(systemName: isTicked ? "checkmark.circle.fill" : "circle")
                .font(.body.weight(.semibold))
                .foregroundStyle(isTicked ? TyfeEditorialPalette.success : TyfeEditorialPalette.muted)
                .accessibilityHidden(true)

            Text(checklistItem.title)
                .font(TyfeTypography.interface)
                .strikethrough(isTicked)
                .foregroundStyle(isTicked ? TyfeEditorialPalette.muted : TyfeEditorialPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 40)
        .contentShape(Rectangle())
        .asButton(.press) {
            guard !isReadOnly, !isDeckDragging else { return }
            onToggleChecklistItem(checklistItem)
        }
        .disabled(isReadOnly || isDeckDragging)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(checklistItem.title)
        .accessibilityValue(isTicked ? "Checked" : "Not checked")
        .accessibilityHint(isReadOnly ? "" : "Double tap to \(isTicked ? "uncheck" : "check")")
    }

    private var editButton: some View {
        Label("Edit", systemImage: "pencil")
            .font(TyfeTypography.interfaceStrong)
            .foregroundStyle(TyfeEditorialPalette.ink)
            .padding(.horizontal, TyfeSpacing.screenInset)
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

    private var startButtonTitle: String {
        if isComplete { return "Completed" }
        return isRewardInProgress ? "Reward in progress" : "Start"
    }

    private var startButtonSystemImage: String {
        if isComplete { return "checkmark" }
        return isRewardInProgress ? "clock.fill" : "play.fill"
    }

    private var progressLabel: String {
        if isChecklist {
            return "\(completedCount) of \(item.plannedSessionCount) done"
        }
        return "\(completedCount) of \(item.plannedSessionCount) sessions"
    }

    private var accessibilityLabel: String {
        var label = "\(activity.name), \(progressLabel)"
        if isChecklist, !checklistItems.isEmpty {
            let tickedCount = checklistItems.filter { tickedItemIds.contains($0.itemId) }.count
            label += ", \(tickedCount) of \(checklistItems.count) items checked"
        }
        guard isRewardInProgress && !isComplete else { return label }
        return label + ". Focus unavailable while Reward is in progress."
    }

}
