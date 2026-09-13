import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    var dashboardState: HomeDashboardState { get }
    var isRewardInProgress: Bool { get }

    func startFocusFromHome() -> FocusSessionModel?
}

extension CoreInteractor: HomeInteractor { }
