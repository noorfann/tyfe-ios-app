import SwiftUI

@MainActor
protocol StarterActivityRouter: GlobalRouter {
    func showDailyPlanView(delegate: DailyPlanDelegate)
}

extension CoreRouter: StarterActivityRouter { }
