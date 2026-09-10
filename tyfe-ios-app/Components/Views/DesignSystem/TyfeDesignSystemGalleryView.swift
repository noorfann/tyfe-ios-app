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
        FocusSessionModel.pausedMock,
        FocusSessionModel.completedMock,
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
            VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                galleryHeader
                warmCanvasSection
                focusChamberSection
                rewardSection
                asyncStateSection
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.card)
        }
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .navigationTitle("Design System")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var galleryHeader: some View {
        HStack(alignment: .top, spacing: TyfeSpacing.control) {
            VStack(alignment: .leading, spacing: TyfeSpacing.small) {
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

    private var warmCanvasSection: some View {
        gallerySection("Warm Canvas") {
            HStack(spacing: TyfeSpacing.control) {
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
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: TyfeSpacing.small
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
                    activityTitle: presenter.activity.name,
                    timeText: timeText(for: session.state),
                    onBegin: {},
                    onPause: {},
                    onResume: {},
                    onAbandon: {}
                )
            }
        }
    }

    private var rewardSection: some View {
        gallerySection("Reward tiers") {
            ForEach(presenter.rewards) { reward in
                TyfeSurfaceView(role: .paper) {
                    VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                        HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
                            Text(reward.name)
                                .font(TyfeTypography.interfaceStrong)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            TyfePillView(
                                label: reward.kind == .starter ? "Starter" : "Custom",
                                systemImage: reward.kind == .starter ? "sparkles" : "pencil",
                                tone: .neutral
                            )
                        }
                        HStack(spacing: TyfeSpacing.small) {
                            Image(systemName: "clock")
                            Text("\(reward.durationTier.durationMinutes) minutes · \(reward.durationTier.creditCost) \(reward.durationTier.creditCost == 1 ? "Credit" : "Credits")")
                                .font(TyfeTypography.interface)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        TyfeActionButtonView(
                            title: reward.availability == .available ? "Take this Reward" : reward.availability.displayName,
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
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
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
        case .paused: return "04:32"
        case .completed: return "00:00"
        case .abandoned: return "08:11"
        }
    }
}

#Preview("Mock gallery") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
}

#Preview("Mock gallery — Dark") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
    .preferredColorScheme(.dark)
}

#Preview("Mock gallery — Large Dynamic Type") {
    NavigationStack {
        TyfeDesignSystemGalleryView(presenter: TyfeDesignSystemGalleryPresenter())
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Mock gallery — Reduce Motion") {
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
