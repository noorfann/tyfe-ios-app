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
    private var isSceneActive = false

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

    var isFocusBlockingRewards: Bool {
        interactor.hasLiveFocusSession
    }

    var claimEndText: String {
        guard let endsAt = (activeClaim ?? finishedClaim)?.endsAt else {
            return "—"
        }
        return Self.endTimeFormatter.string(from: endsAt)
    }

    func onViewAppear(delegate: RewardsDelegate) {
        interactor.trackScreenEvent(event: Event.onAppear(delegate: delegate))
        interactor.prepareSoundEffect(sound: .start, simultaneousPlayers: 1)
        interactor.prepareSoundEffect(sound: .finish, simultaneousPlayers: 1)
        isSceneActive = true
        refresh()
        startTickerIfNeeded()
    }

    func onViewDisappear(delegate: RewardsDelegate) {
        stopTicker()
        isSceneActive = false
        interactor.tearDownSoundEffect(sound: .start)
        interactor.tearDownSoundEffect(sound: .finish)
        interactor.trackEvent(event: Event.onDisappear(delegate: delegate))
    }

    func onSceneBecameActive() {
        isSceneActive = true
        refresh()
        startTickerIfNeeded()
    }

    func onSceneBecameInactive() {
        isSceneActive = false
    }

    func onSelectReward(_ reward: RewardModel) {
        guard !isFocusBlockingRewards else {
            showFocusBlockingAlert()
            return
        }
        interactor.trackEvent(event: Event.selectReward(reward: reward))
        requestClaimConfirmation(for: reward)
    }

    func onStartClaimPressed() {
        guard !isFocusBlockingRewards else {
            showFocusBlockingAlert()
            return
        }
        guard let claim = activeClaim, claim.state == .ready else { return }
        do {
            activeClaim = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
            interactor.playSoundEffect(sound: .start)
            interactor.trackEvent(event: Event.startClaim(claim: claim))
            refresh()
            startTickerIfNeeded()
        } catch RewardManagerError.focusSessionInProgress {
            showFocusBlockingAlert()
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
        guard !isFocusBlockingRewards else {
            showFocusBlockingAlert()
            return
        }
        do {
            var claim = try interactor.createRewardClaim(
                rewardId: reward.rewardId,
                durationTier: reward.durationTier
            )
            if startNow {
                claim = try interactor.startRewardClaim(rewardClaimId: claim.rewardClaimId)
                interactor.playSoundEffect(sound: .start)
            }
            activeClaim = claim
            finishedClaim = nil
            interactor.trackEvent(event: Event.createClaim(reward: reward, startNow: startNow))
            refresh()
            startTickerIfNeeded()
        } catch RewardManagerError.focusSessionInProgress {
            showFocusBlockingAlert()
        } catch {
            showPersistenceAlert()
        }
    }

    private func refresh(playCompletionSound: Bool = false) {
        let wasActive = activeClaim?.state == .active
        interactor.synchronizeRewardCreditDay()
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

            if playCompletionSound,
               wasActive,
               finishedClaim?.state == .expired {
                interactor.playSoundEffect(sound: .finish)
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
                self?.onTimerTick()
            }
        }
    }

    private func onTimerTick() {
        refresh(playCompletionSound: isSceneActive)
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

    private func showFocusBlockingAlert() {
        router.showSimpleAlert(
            title: "Focus Session in progress",
            subtitle: "Finish or abandon Focus before starting a Reward."
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
