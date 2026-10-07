import SwiftUI

@Observable
@MainActor
final class TyfeDesignSystemGalleryPresenter {
    let activity = ActivityModel.mock
    let plan = DailyPlanModel.mock
    let activities = ActivityModel.mocks
    let focusSessions = [
        FocusSessionModel.readyMock,
        FocusSessionModel.runningMock,
        FocusSessionModel.completedMock,
        FocusSessionModel.restingMock,
        FocusSessionModel.abandonedMock
    ]
    let rewards = RewardModel.mocks

    init() {}
}

struct TyfeDesignSystemGalleryView: View {
    @State private var presenter: TyfeDesignSystemGalleryPresenter

    init(presenter: TyfeDesignSystemGalleryPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
                galleryHeader
                spacingSection
                warmCanvasSection
                focusChamberSection
                rewardSection
                asyncStateSection
            }
            .padding(.horizontal, TyfeSpacing.screenInset)
            .padding(.vertical, TyfeSpacing.cardInset)
        }
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var galleryHeader: some View {
        HStack(alignment: .top, spacing: TyfeSpacing.itemGap) {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                Text("Tyfe building blocks")
                    .font(TyfeTypography.displayCompact)
                Text("Mock-only review surface for the Phase 1 production foundation.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            TyfeMotifView(kind: .badge)
        }
        .accessibilityElement(children: .combine)
    }

    private var spacingSection: some View {
        gallerySection("Spacing by relationship") {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.tightGap) {
                        Text("Title and caption · 4 pt").font(TyfeTypography.interfaceStrong)
                        Text("Standard surface inset · 24 pt").font(TyfeTypography.caption)
                    }
                    VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                        HStack(spacing: TyfeSpacing.relatedGap) {
                            Image(systemName: "square.grid.2x2")
                            Text("Related controls · 8 pt")
                        }
                        Text("Items · 16 pt; sections · 24 pt")
                    }
                    .font(TyfeTypography.interface)
                }
            }
            TyfeSurfaceView(role: .paper, contentPadding: TyfeSpacing.compactCardInset) {
                Text("Dense surface · 12 pt; screen gutter · 16 pt; major transition · 32 pt")
                    .font(TyfeTypography.caption)
            }
        }
    }

    private var warmCanvasSection: some View {
        gallerySection("Warm Canvas") {
            HStack(spacing: TyfeSpacing.itemGap) {
                TyfeMetricCardView(
                    title: "Reward Credits",
                    value: "2",
                    detail: "available",
                    systemImage: "circle.fill",
                    accent: TyfeEditorialPalette.saffron
                )
                TyfeMetricCardView(
                    title: "Daily Plan",
                    value: "1/3",
                    detail: "sessions",
                    systemImage: "checkmark.circle.fill",
                    accent: TyfeEditorialPalette.teal
                )
            }
            TyfeActivityCardView(
                activity: presenter.activity,
                sessionCount: 1,
                timeBlock: presenter.plan.timeBlocks?.first,
                onStart: {}
            )
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: TyfeSpacing.relatedGap), GridItem(.flexible(), spacing: TyfeSpacing.relatedGap)],
                spacing: TyfeSpacing.relatedGap
            ) {
                ForEach(FocusSessionState.allCases, id: \.self) { state in
                    TyfeStateBadgeView(state: state)
                }
            }
        }
    }

    private var focusChamberSection: some View {
        gallerySection("Focus Chamber") {
            ForEach(presenter.focusSessions) { session in
                TyfeFocusTimerView(
                    session: session,
                    daypart: .night,
                    activityTitle: presenter.activity.name,
                    timeText: timeText(for: session.state),
                    progress: progress(for: session.state),
                    supportingText: supportingText(for: session),
                    onBegin: {},
                    onAbandon: {}
                )
            }
            TyfeRestTimerView(
                daypart: .night,
                timeText: "04:12",
                progress: 0.84,
                onSkip: {},
                onBackToToday: {}
            )
        }
    }

    private var rewardSection: some View {
        gallerySection("Reward rate") {
            ForEach(presenter.rewards) { reward in
                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                        HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.relatedGap) {
                            Text(reward.name)
                                .font(TyfeTypography.interfaceStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TyfePillView(
                                label: reward.kind == .starter ? "Starter" : "Custom",
                                systemImage: reward.kind == .starter ? "sparkles" : "pencil",
                                tone: .neutral
                            )
                        }
                        HStack(spacing: TyfeSpacing.relatedGap) {
                            Image(systemName: "clock")
                            Text("\(reward.durationTier.durationMinutes) minutes · \(reward.durationTier.creditLabel)")
                                .font(TyfeTypography.interface)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        TyfeActionButtonView(
                            title: reward.availability == .available ? "Claim" : reward.availability.displayName,
                            systemImage: reward.availability == .available ? "gift.fill" : "lock.fill",
                            isEnabled: reward.availability == .available,
                            onTap: {}
                        )
                    }
                }
            }
        }
    }

    private var asyncStateSection: some View {
        gallerySection("Async states") {
            ForEach(TyfeStatusKind.allCases, id: \.self) { kind in
                TyfeStatusView(kind: kind, onRetry: {})
            }
        }
    }

    private func gallerySection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
            Text(title)
                .font(TyfeTypography.eyebrow)
                .textCase(.uppercase)
                .foregroundStyle(TyfeEditorialPalette.muted)
            content()
        }
    }

    private func timeText(for state: FocusSessionState) -> String {
        switch state {
        case .ready: return "25:00"
        case .running: return "18:42"
        case .completed: return "00:00"
        case .abandoned: return "08:11"
        }
    }

    private func progress(for state: FocusSessionState) -> Double {
        switch state {
        case .ready: return 1
        case .running: return 0.75
        case .completed: return 0
        case .abandoned: return 0.33
        }
    }

    private func supportingText(for session: FocusSessionModel) -> String {
        switch session.state {
        case .ready: return "25 minutes of focus"
        case .running: return "Phone lock will not stop the timer"
        case .completed: return "Focus Session complete"
        case .abandoned: return "No Reward Credit earned"
        }
    }
}

#Preview("Mock gallery") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
}

#Preview("Mock gallery - Dark") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
    .preferredColorScheme(.dark)
}

#Preview("Mock gallery - Large Dynamic Type") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Mock gallery - Reduce Motion") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
    .transaction { transaction in
        transaction.animation = nil
    }
}

#if MOCK || DEV
extension CoreBuilder {
    func designSystemGalleryView(router: AnyRouter) -> some View {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
}
#endif
