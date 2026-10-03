import SwiftUI

@MainActor
protocol OnboardingRouter: GlobalRouter {
    func showStarterActivityView(delegate: StarterActivityDelegate)
    func switchToCoreModule()
    func switchToWelcome()
}

extension CoreRouter: OnboardingRouter { }
