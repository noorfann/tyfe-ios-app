import SwiftUI

@MainActor
protocol OnboardingRouter: GlobalRouter {
    func showStarterActivityView(delegate: StarterActivityDelegate)
    func switchToCoreModule()
}

extension CoreRouter: OnboardingRouter { }
