import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showFocusView(delegate: FocusDelegate)
    func showTodayView()
}

extension CoreRouter: HomeRouter { }

extension CoreRouter {
    func showTodayView() {
        showTodayView(delegate: TodayDelegate())
    }
}
