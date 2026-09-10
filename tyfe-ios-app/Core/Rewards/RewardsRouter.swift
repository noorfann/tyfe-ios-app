import SwiftUI

@MainActor
protocol RewardsRouter: GlobalRouter {
    func showRewardsView(delegate: RewardsDelegate)
}

extension CoreRouter: RewardsRouter { }
