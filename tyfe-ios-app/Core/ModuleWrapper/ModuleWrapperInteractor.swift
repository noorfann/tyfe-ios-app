import SwiftUI

@MainActor
protocol ModuleWrapperInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }
    var activeRewardClaim: RewardClaimModel? { get }
}

extension CoreInteractor: ModuleWrapperInteractor {
}
