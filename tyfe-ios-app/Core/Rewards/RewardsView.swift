import SwiftUI
import SwiftfulUI

struct RewardsDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct RewardsView: View {

    @State private var presenter: RewardsPresenter
    let delegate: RewardsDelegate

    @Environment(\.scenePhase) private var scenePhase

    init(presenter: RewardsPresenter, delegate: RewardsDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    summaryCards
                    focusBlockingNotice
                    claimSection
                    starterSection
                    customSection
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .tyfeBottomSheet(
            isPresented: $presenter.isCreateSheetPresented,
            title: "New Reward"
        ) {
            RewardsCreateRewardSheet(onSave: presenter.onCreateReward)
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                presenter.onSceneBecameActive()
            }
        }
    }

    @ViewBuilder
    private var focusBlockingNotice: some View {
        if presenter.isFocusBlockingRewards {
            TyfeSurfaceView(role: .warning) {
                Label(
                    "Finish or abandon Focus before starting a Reward.",
                    systemImage: "timer"
                )
                .font(TyfeTypography.interfaceStrong)
            }
            .accessibilityLabel("Rewards unavailable while Focus is active")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Rewards")
                .font(TyfeTypography.display)
                .tracking(-1.6)

            Text("Bounded downtime, earned by focus.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private func balanceCard(minContentHeight: CGFloat? = nil) -> some View {
        TyfeMetricCardView(
            title: "Credits",
            value: String(presenter.balance),
            systemImage: "creditcard.rewards",
            accent: TyfeEditorialPalette.saffron,
            minContentHeight: minContentHeight
        )
    }

    private var summaryCards: some View {
        ViewThatFits(in: .horizontal) {
            GeometryReader { proxy in
                let spacing = TyfeSpacing.control
                let cardWidth = max(0, proxy.size.width - spacing)

                HStack(alignment: .top, spacing: spacing) {
                    balanceCard(minContentHeight: Self.summaryCardContentHeight)
                        .frame(width: cardWidth * 0.4)

                    TyfeTierLegendView(minContentHeight: Self.summaryCardContentHeight)
                        .frame(width: cardWidth * 0.6)
                }
            }
            .frame(minWidth: Self.summaryRowMinimumWidth, maxWidth: .infinity)
            .frame(height: Self.summaryCardHeight)

            VStack(spacing: TyfeSpacing.section) {
                balanceCard()
                TyfeTierLegendView()
            }
        }
    }

    @ViewBuilder
    private var claimSection: some View {
        if let claim = presenter.activeClaim {
            if claim.state == .ready {
                TyfeClaimCardView(
                    claim: claim,
                    remainingSeconds: presenter.remainingClaimSeconds,
                    endText: presenter.claimEndText,
                    startBlockingMessage: presenter.isFocusBlockingRewards
                        ? "Finish or abandon Focus before starting this Reward."
                        : nil,
                    onStart: presenter.onStartClaimPressed
                )
            }
        } else if let finished = presenter.finishedClaim {
            TyfeClaimCardView(
                claim: finished,
                remainingSeconds: 0,
                endText: presenter.claimEndText,
                onStart: {}
            )
        }
    }

    private var starterSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            sectionTitle("STARTER REWARDS")

            rewardCarousel(presenter.starterRewards)
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            sectionTitle("YOUR REWARDS")

            if presenter.customRewards.isEmpty {
                Text("Add your own bounded downtime option.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            } else {
                rewardCarousel(presenter.customRewards)
            }

            TyfeActionButtonView(
                title: "Create a custom Reward",
                systemImage: "plus",
                role: .secondary,
                onTap: presenter.onCreateRewardPressed
            )
        }
    }

    private func rewardCarousel(_ rewards: [RewardModel]) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: TyfeSpacing.control) {
                ForEach(rewards) { reward in
                    TyfeRewardCardView(
                        reward: reward,
                        balance: presenter.balance,
                        blockingMessage: presenter.isFocusBlockingRewards
                            ? "Finish or abandon Focus before claiming a Reward."
                            : nil,
                        onTap: { presenter.onSelectReward(reward) }
                    )
                    .frame(width: Self.rewardCardWidth)
                }
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.unit)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -TyfeSpacing.control)
        .accessibilityLabel("Rewards, scroll sideways for more")
    }

    private static let rewardCardWidth: CGFloat = 260
    private static let summaryCardHeight: CGFloat = 132
    private static let summaryCardContentHeight: CGFloat = summaryCardHeight - (TyfeSpacing.card * 2)
    private static let summaryRowMinimumWidth: CGFloat = 320

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(TyfeTypography.eyebrow)
            .tracking(1.2)
            .foregroundStyle(TyfeEditorialPalette.muted)
    }
}

#Preview("Rewards") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.rewardsView(router: router, delegate: RewardsDelegate())
    }
}

extension CoreBuilder {

    func rewardsView(router: AnyRouter, delegate: RewardsDelegate) -> some View {
        RewardsView(
            presenter: RewardsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {

    func showRewardsView(delegate: RewardsDelegate = RewardsDelegate()) {
        router.showScreen(.push) { router in
            builder.rewardsView(router: router, delegate: delegate)
        }
    }
}
