import SwiftUI

@MainActor
protocol OnboardingInteractor: GlobalInteractor {
    func requestNotificationAuthorizationIfNeeded() async -> Bool
}

extension CoreInteractor: OnboardingInteractor {
    func requestNotificationAuthorizationIfNeeded() async -> Bool {
        guard await canRequestPushAuthorization() else { return false }
        return (try? await requestPushAuthorization()) ?? false
    }
}
