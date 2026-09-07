import SwiftUI

@MainActor
protocol HomeInteractor: GlobalInteractor {
    var dashboardState: HomeDashboardState { get }

    func startFocusFromHome() -> FocusSessionModel?
}

extension CoreInteractor: HomeInteractor { }
