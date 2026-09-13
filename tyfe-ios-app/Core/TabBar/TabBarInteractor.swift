import SwiftUI

@MainActor
protocol TabBarInteractor: GlobalInteractor {
    var activeRewardClaim: RewardClaimModel? { get }
    var activeFocusSession: FocusSessionModel? { get }
    var isFocusInProgress: Bool { get }
    var isFocusScreenVisible: Bool { get }

    @discardableResult
    func refreshRewardClaim() throws -> RewardClaimModel?

    func refreshFocusSession(focusSessionId: String) throws -> FocusSessionRefresh
    func activity(forFocusSession session: FocusSessionModel) -> ActivityModel?
}

extension CoreInteractor: TabBarInteractor { }
