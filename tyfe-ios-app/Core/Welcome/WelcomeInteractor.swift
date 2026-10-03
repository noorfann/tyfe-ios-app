import Foundation

@MainActor
protocol WelcomeInteractor: GlobalInteractor {
    var entryPhase: AppEntryPhase { get }
    var pendingEmailRegistration: PendingEmailRegistration? { get }
    func prepareGuestForSignup() async throws
    func setEntryPhase(_ phase: AppEntryPhase)
    func prepareEntryTransition(to phase: AppEntryPhase)
    func completeEntryTransition()
}

extension CoreInteractor: WelcomeInteractor { }
