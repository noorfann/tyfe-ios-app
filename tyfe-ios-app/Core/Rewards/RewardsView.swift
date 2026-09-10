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
                    balanceCard
                    claimSection
                    TyfeTierLegendView()
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
        .sheet(isPresented: $presenter.isCreateSheetPresented) {
            RewardsCreateRewardSheet(
                onSave: presenter.onCreateReward,
                onCancel: presenter.onDismissCreateSheet
            )
            .presentationDetents([.medium])
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

    private var balanceCard: some View {
        TyfeMetricCardView(
            title: "Credits",
            value: String(presenter.balance),
            detail: "Reward Credits",
            systemImage: "circle.fill",
            accent: TyfeEditorialPalette.saffron
        )
    }

    @ViewBuilder
    private var claimSection: some View {
        if let claim = presenter.activeClaim {
            if claim.state == .ready {
                TyfeClaimCardView(
                    claim: claim,
                    remainingSeconds: presenter.remainingClaimSeconds,
                    endText: presenter.claimEndText,
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
