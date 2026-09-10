import SwiftUI

@MainActor
protocol TabBarInteractor: GlobalInteractor {
    var activeRewardClaim: RewardClaimModel? { get }
    var isFocusScreenVisible: Bool { get }

    @discardableResult
    func refreshRewardClaim() throws -> RewardClaimModel?
}

extension CoreInteractor: TabBarInteractor { }
