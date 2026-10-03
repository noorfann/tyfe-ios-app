import SwiftUI

@Observable
@MainActor
final class WelcomePresenter {
    private let interactor: WelcomeInteractor
    private let router: WelcomeRouter
    private(set) var isPreparingSignup = false
    private(set) var isAuthPresented = false
    private(set) var errorMessage: String?
    @ObservationIgnored private(set) var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var presentationId: UUID?
    @ObservationIgnored private var hasCompletedAuthentication = false

    init(interactor: WelcomeInteractor, router: WelcomeRouter) {
        self.interactor = interactor
        self.router = router
    }

    var accountActionTitle: String {
        if isPreparingSignup { return "Preparing account…" }
        return interactor.pendingEmailRegistration == nil ? "Create account" : "Finish creating account"
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.appear)
    }

    func onCreateAccountPressed() {
        guard !isPreparingSignup, !isAuthPresented, interactor.entryPhase == .welcome else { return }
        interactor.trackEvent(event: Event.action("CreateAccount"))
        isPreparingSignup = true
        errorMessage = nil
        preparationTask = Task {
            defer { isPreparingSignup = false }
            do {
                try await interactor.prepareGuestForSignup()
                guard !Task.isCancelled, interactor.entryPhase == .welcome else { return }
                let id = beginPresentation()
                router.showSignUpView(
                    delegate: SignUpDelegate(
                        onDidSignIn: { [weak self] in self?.onAuthenticated(to: .onboarding, id: id) },
                        onDidSignInToExistingAccount: { [weak self] in self?.onAuthenticated(to: .core, id: id) }
                    ),
                    onDismiss: { [weak self] in self?.onAuthDismissed(id: id) }
                )
            } catch {
                guard !Task.isCancelled, interactor.entryPhase == .welcome else { return }
                errorMessage = error.localizedDescription
                interactor.trackEvent(event: Event.action("PreparationFailed"))
            }
        }
    }

    func onSignInPressed() {
        guard !isPreparingSignup, !isAuthPresented, interactor.entryPhase == .welcome else { return }
        interactor.trackEvent(event: Event.action("SignIn"))
        errorMessage = nil
        let id = beginPresentation()
        router.showSignInSheet(
            onDidSignIn: { [weak self] in self?.onAuthenticated(to: .core, id: id) },
            onDismiss: { [weak self] in self?.onAuthDismissed(id: id) }
        )
    }

    func onContinueAsGuestPressed() {
        guard !isAuthPresented, interactor.entryPhase == .welcome else { return }
        preparationTask?.cancel()
        interactor.trackEvent(event: Event.action("ContinueAsGuest"))
        interactor.setEntryPhase(.onboarding)
    }

    private func beginPresentation() -> UUID {
        let id = UUID()
        presentationId = id
        hasCompletedAuthentication = false
        isAuthPresented = true
        return id
    }

    private func onAuthenticated(to phase: AppEntryPhase, id: UUID) {
        guard presentationId == id, !hasCompletedAuthentication, interactor.entryPhase == .welcome else { return }
        hasCompletedAuthentication = true
        interactor.prepareEntryTransition(to: phase)
        interactor.trackEvent(event: Event.action(phase == .core ? "SignInCompleted" : "SignupCompleted"))
    }

    private func onAuthDismissed(id: UUID) {
        guard presentationId == id else { return }
        presentationId = nil
        isAuthPresented = false
        if hasCompletedAuthentication { interactor.completeEntryTransition() }
        hasCompletedAuthentication = false
    }
}

extension WelcomePresenter {
    enum Event: LoggableEvent {
        case appear
        case action(String)

        var eventName: String {
            switch self {
            case .appear: return "WelcomeView_Appear"
            case .action(let action): return "WelcomeView_\(action)"
            }
        }
        var parameters: [String: Any]? { nil }
        var type: LogType { .analytic }
    }
}
