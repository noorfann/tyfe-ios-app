import SwiftUI

@Observable
@MainActor
final class RewardsPresenter {

    private let interactor: RewardsInteractor
    private let router: RewardsRouter

    private(set) var balance = 0
    private(set) var rewards: [RewardModel] = []
    private(set) var activeClaim: RewardClaimModel?
    private(set) var finishedClaim: RewardClaimModel?
    private(set) var remainingClaimSeconds = 0

    var isCreateSheetPresented = false

    private var tickerTask: Task<Void, Never>?

    init(interactor: RewardsInteractor, router: RewardsRouter) {
        self.interactor = interactor
        self.router = router
    }

    var starterRewards: [RewardModel] {
        rewards.filter { $0.kind == .starter }
    }

    var customRewards: [RewardModel] {
        rewards.filter { $0.kind == .custom }
    }

    var claimEndText: String {
        guard let endsAt = (activeClaim ?? finishedClaim)?.endsAt else {
            return "—"
        }
        return Self.endTimeFormatter.string(from: endsAt)
    }

    func onViewAppear(delegate: RewardsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        refresh()
        startTickerIfNeeded()
    }

    func onViewDisappear(delegate: RewardsDelegate) {
        stopTicker()
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onSceneBecameActive() {
        refresh()
        startTickerIfNeeded()
    }

    func onSelectReward(_ reward: RewardModel) {
        interactor.trackEvent(event: Event.selectReward(reward: reward))
        requestClaimConfirmation(for: reward)
    }

    func onStartClaimPressed() {
        guard let claim = activeClaim, claim.state == .ready else { return }
        do {
            activeClaim = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
            interactor.trackEvent(event: Event.startClaim(claim: claim))
            refresh()
            startTickerIfNeeded()
        } catch {
            showPersistenceAlert()
        }
    }

    func onCreateRewardPressed() {
        isCreateSheetPresented = true
    }

    func onCreateReward(name: String, durationTier: RewardDurationTier) {
        _ = interactor.createCustomReward(name: name, durationTier: durationTier)
        isCreateSheetPresented = false
        refresh()
    }

    func onBackToTodayPressed() {
        router.dismissScreen()
    }

    private func requestClaimConfirmation(for reward: RewardModel) {
        let cost = reward.durationTier.creditCost
        let remaining = max(balance - cost, 0)
        let costText = cost == 1 ? "1 Reward Credit" : "\(cost) Reward Credits"

        router.showAlert(
            .alert,
            title: "Claim \(reward.name)?",
            subtitle: "\(reward.durationTier.durationMinutes) minutes for \(costText). Balance after claim: \(remaining).",
            buttons: {
                AnyView(
                    Group {
                        Button("Start now") {
                            self.createClaim(for: reward, startNow: true)
                        }
                        Button("Start later") {
                            self.createClaim(for: reward, startNow: false)
                        }
                        Button("Cancel", role: .cancel) { }
                    }
                )
            }
        )
    }

    private func createClaim(for reward: RewardModel, startNow: Bool) {
        do {
            var claim = try interactor.createRewardClaim(
                rewardId: reward.rewardId,
                durationTier: reward.durationTier
            )
            if startNow {
                claim = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
            }
            activeClaim = claim
            finishedClaim = nil
            interactor.trackEvent(event: Event.createClaim(reward: reward, startNow: startNow))
            refresh()
            startTickerIfNeeded()
        } catch {
            showPersistenceAlert()
        }
    }

    private func refresh() {
        do {
            let refreshed = try interactor.refreshRewardClaim()

            if let refreshed, refreshed.state != .expired {
                activeClaim = refreshed
                finishedClaim = nil
                remainingClaimSeconds = remainingSeconds(for: refreshed)
            } else {
                activeClaim = nil
                finishedClaim = refreshed ?? interactor.rewardClaims.last { $0.state == .expired }
                remainingClaimSeconds = 0
            }

            rewards = interactor.rewards
            balance = interactor.rewardCredits

            if activeClaim?.state != .active {
                stopTicker()
            }
        } catch {
            showPersistenceAlert()
        }
    }

    private func remainingSeconds(for claim: RewardClaimModel) -> Int {
        guard claim.state == .active, let endsAt = claim.endsAt else { return 0 }
        return max(Int(ceil(endsAt.timeIntervalSinceNow)), 0)
    }

    private func startTickerIfNeeded() {
        guard activeClaim?.state == .active else { return }
        stopTicker()
        tickerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private func stopTicker() {
        tickerTask?.cancel()
        tickerTask = nil
    }

    private func showPersistenceAlert() {
        router.showAlert(
            .alert,
            title: "Couldn't update Rewards",
            subtitle: "Your Reward Credits are still safe. Please try that action again.",
            buttons: {
                AnyView(Button("OK", role: .cancel) { })
            }
        )
    }

    private static let endTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

extension RewardsPresenter {

    enum Event: LoggableEvent {
        case onAppear(delegate: RewardsDelegate)
        case onDisappear(delegate: RewardsDelegate)
        case selectReward(reward: RewardModel)
        case createClaim(reward: RewardModel, startNow: Bool)
        case startClaim(claim: RewardClaimModel)

        var eventName: String {
            switch self {
            case .onAppear:     return "RewardsView_Appear"
            case .onDisappear:  return "RewardsView_Disappear"
            case .selectReward: return "RewardsView_SelectReward"
            case .createClaim:  return "RewardsView_CreateClaim"
            case .startClaim:   return "RewardsView_StartClaim"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .onAppear(delegate: let delegate), .onDisappear(delegate: let delegate):
                return delegate.eventParameters
            case .selectReward(reward: let reward):
                return reward.eventParameters
            case .createClaim(reward: let reward, startNow: let startNow):
                var params = reward.eventParameters
                params["start_now"] = startNow
                return params
            case .startClaim(claim: let claim):
                return claim.eventParameters
            }
        }

        var type: LogType {
            .analytic
        }
    }
}
