import SwiftUI

@MainActor
protocol TodayRouter: GlobalRouter {
    func showStarterActivityView(delegate: StarterActivityDelegate)
    func showDailyPlanView(delegate: DailyPlanDelegate)
    func showFocusView(delegate: FocusDelegate)
    #if MOCK || DEV
    func showDevSettingsView()
    #endif
}

extension CoreRouter: TodayRouter { }
