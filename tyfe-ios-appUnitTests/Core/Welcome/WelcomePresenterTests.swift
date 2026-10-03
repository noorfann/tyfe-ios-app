import Foundation
import SwiftfulRouting
import Testing
@testable import tyfe_ios_app

@MainActor
struct WelcomePresenterTests {
    @Test func backgroundGuestBootstrapDoesNotChooseGuestOrHideWelcome() async throws {
        let context = try makeContext(withoutSession: true)
        let presenter = AppPresenter(interactor: context.interactor)
        await presenter.checkUserStatus()
        #expect(context.interactor.auth?.isAnonymous == true)
        #expect(context.interactor.entryPhase == .welcome)
    }

    @Test func guestChoicePreservesLocalProgressAndLocksCircles() throws {
        let context = try makeContext()
        let before = context.repository.snapshot
        context.presenter.onContinueAsGuestPressed()
        #expect(context.interactor.entryPhase == .onboarding)
        #expect(context.repository.snapshot == before)
        #expect(!context.interactor.canAccessCircles)
        #expect(context.router.signupDelegate == nil)
        #expect(context.router.signInCompletion == nil)
    }

    @Test func cancelledSignInLeavesWelcomeAndStaleCallbackIsIgnored() throws {
        let context = try makeContext()
        context.presenter.onSignInPressed()
        let staleCompletion = context.router.signInCompletion
        context.router.onDismiss?()
        #expect(context.interactor.entryPhase == .welcome)
        context.presenter.onSignInPressed()
        staleCompletion?()
        context.router.onDismiss?()
        #expect(context.interactor.entryPhase == .welcome)
    }

    @Test func successfulSignInWaitsForDismissalThenOpensCoreOnce() throws {
        let context = try makeContext()
        context.presenter.onSignInPressed()
        context.router.signInCompletion?()
        context.router.signInCompletion?()
        #expect(context.interactor.entryPhase == .welcome)
        context.router.onDismiss?()
        context.router.onDismiss?()
        #expect(context.interactor.entryPhase == .core)
    }

    @Test func signupWaitsForDoneAndExistingAccountFallbackOpensToday() async throws {
        let signup = try makeContext()
        signup.presenter.onCreateAccountPressed()
        await signup.presenter.preparationTask?.value
        signup.router.signupDelegate?.onDidSignIn?()
        #expect(signup.interactor.entryPhase == .welcome)
        signup.router.onDismiss?()
        #expect(signup.interactor.entryPhase == .onboarding)

        let existing = try makeContext()
        existing.presenter.onCreateAccountPressed()
        await existing.presenter.preparationTask?.value
        existing.router.signupDelegate?.onDidSignInToExistingAccount?()
        existing.router.onDismiss?()
        #expect(existing.interactor.entryPhase == .core)
    }

    @Test func duplicateCreateTapsAndGuestCancellationCannotPresentLateSignup() async throws {
        let context = try makeContext()
        context.presenter.onCreateAccountPressed()
        context.presenter.onCreateAccountPressed()
        context.presenter.onContinueAsGuestPressed()
        await context.presenter.preparationTask?.value
        #expect(context.interactor.entryPhase == .onboarding)
        #expect(context.router.signupDelegate == nil)
        #expect(!context.presenter.isPreparingSignup)
    }

    @Test func unavailableAuthenticationStillAllowsGuestUse() async throws {
        let context = try makeContext(unavailable: true)
        context.presenter.onCreateAccountPressed()
        await context.presenter.preparationTask?.value
        #expect(context.presenter.errorMessage == EmailAuthError.notConfigured.errorDescription)
        #expect(context.interactor.entryPhase == .welcome)
        #expect(context.router.signupDelegate == nil)
        context.presenter.onContinueAsGuestPressed()
        #expect(context.interactor.entryPhase == .onboarding)
    }

    @Test func unfinishedSignupOffersResumeAndGuestKeepsCirclesLocked() async throws {
        let context = try makeContext()
        _ = try await context.interactor.beginEmailRegistration(email: "person@example.com", displayName: nil)
        _ = try await context.interactor.verifyEmailRegistrationCode("123456")
        #expect(context.presenter.accountActionTitle == "Finish creating account")
        context.presenter.onContinueAsGuestPressed()
        #expect(context.interactor.pendingEmailRegistration?.stage == .password)
        #expect(!context.interactor.canAccessCircles)
    }

    @Test func signOutReturnsToWelcomeWithoutDeletingLocalProgress() async throws {
        let context = try makeContext()
        context.interactor.setEntryPhase(.core)
        let before = context.repository.snapshot
        try await context.interactor.signOut()
        #expect(context.interactor.entryPhase == .welcome)
        #expect(context.repository.snapshot == before)
        #expect(!context.interactor.canAccessCircles)
    }

    @Test func explicitSignOutClearsPendingRegistration() async throws {
        let context = try makeContext()
        _ = try await context.interactor.beginEmailRegistration(email: "person@example.com", displayName: nil)
        try await context.interactor.signOut()
        #expect(context.interactor.pendingEmailRegistration == nil)
        #expect(context.interactor.entryPhase == .welcome)
    }

    @Test func accountDeletionReturnsToWelcomeAndPreservesOnDeviceActivities() async throws {
        let context = try makeContext()
        let user = try #require(context.interactor.auth)
        try await context.interactor.logIn(user: user, isNewUser: true)
        context.interactor.setEntryPhase(.core)
        let before = context.repository.snapshot
        try await context.interactor.deleteAccount()
        #expect(context.interactor.entryPhase == .welcome)
        #expect(context.repository.snapshot == before)
        #expect(context.interactor.auth == nil)
    }

    @Test func onboardingBackMovesThroughPagesThenReturnsToWelcome() throws {
        let context = try makeContext()
        let presenter = OnboardingPresenter(interactor: context.interactor, router: context.router)
        presenter.goNext()
        presenter.goBack()
        #expect(presenter.currentIndex == 0)
        #expect(context.router.welcomeCount == 0)
        presenter.goBack()
        #expect(context.router.welcomeCount == 1)
    }

    private func makeContext(unavailable: Bool = false, withoutSession: Bool = false) throws -> WelcomeTestContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
        let service = MockEmailAuthService(user: withoutSession ? nil : .mock(isAnonymous: true))
        dependencies.container.register(AuthManager.self, service: AuthManager(service: service))
        let email: any EmailAuthServicing = unavailable ? UnavailableEmailAuthService() : service
        dependencies.container.register(EmailAuthServicing.self, service: email)
        let interactor = CoreInteractor(container: dependencies.container)
        let router = WelcomeTestRouter()
        return WelcomeTestContext(
            presenter: WelcomePresenter(interactor: interactor, router: router), interactor: interactor,
            router: router, repository: try #require(dependencies.container.resolve(LocalAppRepository.self))
        )
    }
}

@MainActor
private struct WelcomeTestContext {
    let presenter: WelcomePresenter
    let interactor: CoreInteractor
    let router: WelcomeTestRouter
    let repository: any LocalAppRepository
}

@MainActor
private final class WelcomeTestRouter: WelcomeRouter, OnboardingRouter {
    var router: AnyRouter { fatalError("Routing storage is unused by this test double") }
    var signupDelegate: SignUpDelegate?
    var signInCompletion: (() -> Void)?
    var onDismiss: (() -> Void)?
    var welcomeCount = 0

    func showSignUpView(delegate: SignUpDelegate, onDismiss: (() -> Void)?) {
        signupDelegate = delegate
        self.onDismiss = onDismiss
    }
    func showSignInSheet(onDidSignIn: (() -> Void)?, onDismiss: (() -> Void)?) {
        signInCompletion = onDidSignIn
        self.onDismiss = onDismiss
    }
    func showStarterActivityView(delegate: StarterActivityDelegate) {}
    func switchToCoreModule() {}
    func switchToWelcome() { welcomeCount += 1 }
}
