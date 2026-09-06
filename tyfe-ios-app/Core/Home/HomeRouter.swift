import SwiftUI

@MainActor
protocol HomeRouter: GlobalRouter {
    func showDevSettingsView()
    func showFocusView(delegate: FocusDelegate)
}

extension CoreRouter: HomeRouter { }
