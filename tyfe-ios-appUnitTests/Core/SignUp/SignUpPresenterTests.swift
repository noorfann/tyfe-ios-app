import Foundation
import SwiftfulRouting
import Testing
@testable import tyfe_ios_app

@MainActor
struct SignUpPresenterTests {
    @Test func successRequiresEveryStageAndDoesNotDismissUntilDone() async {
        let context = makeContext()
        var completionCount = 0
        let delegate = SignUpDelegate(onDidSignIn: { completionCount += 1 })
        context.presenter.email = "person@example.com"
        context.presenter.onSubmitPressed(delegate: delegate)
        await context.presenter.submissionTask?.value
        #expect(context.presenter.step == .verification)
        #expect(completionCount == 0)

        context.presenter.code = "123456"
        context.presenter.onSubmitPressed(delegate: delegate)
        await context.presenter.submissionTask?.value
        #expect(context.presenter.step == .password)
        #expect(completionCount == 0)

        context.presenter.password = "secret123"
        context.presenter.onSubmitPressed(delegate: delegate)
        await context.presenter.submissionTask?.value
        #expect(context.presenter.step == .complete)
        #expect(completionCount == 1)
        #expect(context.presenter.password.isEmpty)
        #expect(context.interactor.pendingEmailRegistration == nil)
        #expect(context.router.dismissCount == 0)

        context.presenter.onSubmitPressed(delegate: delegate)
        #expect(context.router.dismissCount == 1)
        #expect(completionCount == 1)
    }

    @Test func duplicateSubmitsCloseAndFieldEditsAreBlockedDuringWrites() async {
        let context = makeContext()
        context.presenter.email = "person@example.com"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        context.presenter.onClosePressed()
        context.presenter.onFieldValueChanged("different@example.com", for: .email)
        #expect(context.presenter.isSubmitting)
        #expect(context.router.dismissCount == 0)
        #expect(context.presenter.email == "person@example.com")
        await context.presenter.submissionTask?.value
        #expect(context.interactor.beginCount == 1)
        #expect(context.interactor.pendingEmailRegistration?.email == "person@example.com")
    }

    @Test func invalidCodeStaysOnVerificationWithUsefulError() async {
        let context = makeContext()
        await advanceToCode(context)
        context.presenter.code = "111111"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
        #expect(context.presenter.step == .verification)
        #expect(context.presenter.errorMessage == EmailAuthError.invalidCode.errorDescription)
        #expect(context.presenter.code == "111111")
        #expect(!context.presenter.isSubmitting)
    }

    @Test func profileFailureResumesWithoutRepeatingRegistrationOrPasswordWrite() async {
        let context = makeContext()
        await advanceToCode(context)
        context.presenter.code = "123456"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
        context.interactor.profileFailuresRemaining = 1
        context.presenter.password = "secret123"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
        #expect(context.presenter.step == .profile)
        #expect(context.presenter.errorMessage?.contains("Your password is saved") == true)

        let resumed = SignUpPresenter(interactor: context.interactor, router: context.router)
        #expect(resumed.step == .profile)
        #expect(resumed.password.isEmpty)
        resumed.onSubmitPressed(delegate: SignUpDelegate())
        await resumed.submissionTask?.value
        #expect(resumed.step == .complete)
        #expect(context.interactor.beginCount == 1)
        #expect(context.interactor.verifyCount == 1)
    }

    @Test func closeAndReopenRestoreEmailAndStageButNeverSecrets() async {
        let context = makeContext()
        await advanceToCode(context)
        context.presenter.code = "123456"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
        context.presenter.password = "unsaved-secret"
        context.presenter.onClosePressed()
        let resumed = SignUpPresenter(interactor: context.interactor, router: context.router)
        await resumed.onFirstTask()
        #expect(resumed.email == "person@example.com")
        #expect(resumed.step == .password)
        #expect(resumed.password.isEmpty)
        #expect(resumed.code.isEmpty)
    }

    @Test func existingAccountErrorOffersSignInWithTrimmedEmail() async {
        let context = makeContext()
        context.interactor.beginError = .emailAlreadyInUse
        context.presenter.email = "  person@example.com  "
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
        #expect(context.presenter.offersSignIn)
        context.presenter.onSignInPressed(delegate: SignUpDelegate())
        #expect(context.router.signInEmail == "person@example.com")
    }

    @Test func missingConfigurationDisablesAccountCreation() async {
        let context = makeContext(service: UnavailableEmailAuthService())
        await context.presenter.onFirstTask()
        context.presenter.email = "person@example.com"
        #expect(context.presenter.isUnavailable)
        #expect(!context.presenter.canSubmit)
        #expect(context.presenter.errorMessage == EmailAuthError.notConfigured.errorDescription)
    }

    @Test func existingAccountCallbackIsDistinctAndLegacyDelegatesStillReceiveCompletion() {
        let context = makeContext()
        var signupCount = 0
        var existingCount = 0
        context.presenter.onSignInPressed(delegate: SignUpDelegate(
            onDidSignIn: { signupCount += 1 },
            onDidSignInToExistingAccount: { existingCount += 1 }
        ))
        context.router.signInCompletion?()
        #expect(signupCount == 0)
        #expect(existingCount == 1)

        context.presenter.onSignInPressed(delegate: SignUpDelegate(onDidSignIn: { signupCount += 1 }))
        context.router.signInCompletion?()
        #expect(signupCount == 1)
    }

    @Test func validationAppearsAfterInteractionAndCodePasteIsNormalized() {
        let context = makeContext()
        #expect(context.presenter.validationMessage(for: .email) == nil)
        context.presenter.onFieldEndedEditing(.email)
        #expect(context.presenter.validationMessage(for: .email) != nil)
        context.presenter.onFieldValueChanged("person@example.com", for: .email)
        #expect(context.presenter.validationMessage(for: .email) == nil)
        context.presenter.onFieldValueChanged("123 456\n", for: .code)
        #expect(context.presenter.code == "123456")
    }

    private func makeContext(service: (any EmailAuthServicing)? = nil) -> SignupPresenterTestContext {
        let interactor = SignupTestInteractor(service: service ?? MockEmailAuthService(user: .mock(isAnonymous: true)))
        let router = SignupTestRouter()
        return SignupPresenterTestContext(
            presenter: SignUpPresenter(interactor: interactor, router: router),
            interactor: interactor, router: router
        )
    }

    private func advanceToCode(_ context: SignupPresenterTestContext) async {
        context.presenter.email = "person@example.com"
        context.presenter.onSubmitPressed(delegate: SignUpDelegate())
        await context.presenter.submissionTask?.value
    }
}

@MainActor
private struct SignupPresenterTestContext {
    let presenter: SignUpPresenter
    let interactor: SignupTestInteractor
    let router: SignupTestRouter
}

@MainActor
private final class SignupTestInteractor: SignUpInteractor {
    let service: any EmailAuthServicing
    let suggestedDisplayName: String? = "Ada"
    var beginError: EmailAuthError?
    var profileFailuresRemaining = 0
    var beginCount = 0
    var verifyCount = 0
    var pendingEmailRegistration: PendingEmailRegistration? { service.pendingRegistration }

    init(service: any EmailAuthServicing) { self.service = service }

    func restoreEmailRegistration() async throws -> PendingEmailRegistration? {
        try await service.restoreRegistration()
    }

    func beginEmailRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration {
        beginCount += 1
        if let beginError { throw beginError }
        return try await service.beginRegistration(email: email, displayName: displayName)
    }

    func verifyEmailRegistrationCode(_ code: String) async throws -> PendingEmailRegistration {
        verifyCount += 1
        return try await service.verifyRegistrationCode(code)
    }

    func resendEmailRegistrationCode() async throws -> PendingEmailRegistration {
        try await service.resendRegistrationCode()
    }

    func finishEmailRegistration(password: String) async throws {
        _ = try await service.finishRegistration(password: password)
        if profileFailuresRemaining > 0 {
            profileFailuresRemaining -= 1
            throw URLError(.cannotWriteToFile)
        }
        try service.acknowledgeRegistrationComplete()
    }

    func trackEvent(eventName: String, parameters: [String: Any]?, type: LogType) {}
    func trackEvent(event: AnyLoggableEvent) {}
    func trackEvent(event: LoggableEvent) {}
    func trackScreenEvent(event: LoggableEvent) {}
    func prepareHaptic(option: HapticOption) {}
    func prepareHaptics(options: [HapticOption]) {}
    func playHaptic(option: HapticOption) {}
    func playHaptics(options: [HapticOption]) {}
    func tearDownHaptic(option: HapticOption) {}
    func tearDownHaptics(options: [HapticOption]) {}
    func tearDownAllHaptics() {}
    func prepareSoundEffect(sound: SoundEffectFile, simultaneousPlayers: Int) {}
    func playSoundEffect(sound: SoundEffectFile) {}
    func tearDownSoundEffect(sound: SoundEffectFile) {}
}

@MainActor
private final class SignupTestRouter: SignUpRouter {
    var router: AnyRouter { fatalError("Routing storage is unused by this test double") }
    var dismissCount = 0
    var signInEmail: String?
    var signInCompletion: (() -> Void)?

    func dismissScreen() { dismissCount += 1 }
    func showSignInView(email: String, onDidSignIn: (() -> Void)?) {
        signInEmail = email
        signInCompletion = onDidSignIn
    }
}
