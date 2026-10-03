import SwiftUI

@Observable
@MainActor
final class SignUpPresenter {
    enum Step: String {
        case details, verification, password, profile, complete
    }

    enum Field: Hashable {
        case displayName, email, code, password
    }

    private let interactor: SignUpInteractor
    private let router: SignUpRouter

    var email = ""
    var displayName = ""
    var password = ""
    var code = ""
    private(set) var step: Step = .details
    private(set) var isSubmitting = false
    private(set) var isRestoring = false
    private(set) var isUnavailable = false
    private(set) var isPasswordVisible = false
    private(set) var errorMessage: String?
    private(set) var offersSignIn = false
    private(set) var resendSecondsRemaining = 0
    private var touchedFields: Set<Field> = []
    @ObservationIgnored private(set) var submissionTask: Task<Void, Never>?

    init(interactor: SignUpInteractor, router: SignUpRouter) {
        self.interactor = interactor
        self.router = router
        applyPending(interactor.pendingEmailRegistration)
    }

    var isBusy: Bool { isSubmitting || isRestoring }

    var isEmailVerified: Bool {
        let stage = interactor.pendingEmailRegistration?.stage
        return stage == .password || stage == .profile
    }

    var canGoBack: Bool {
        step == .password || (step == .verification && !isEmailVerified)
    }

    var canSubmit: Bool {
        guard !isBusy, !isUnavailable else { return false }
        switch step {
        case .details:
            return EmailCredentialValidator.isValidEmail(email) && resendSecondsRemaining == 0
        case .verification:
            return isEmailVerified || EmailCredentialValidator.isValidCode(code)
        case .password:
            return EmailCredentialValidator.isValidPassword(password)
        case .profile, .complete:
            return true
        }
    }

    var primaryButtonTitle: String {
        if isRestoring { return "Restoring account setup…" }
        if isSubmitting {
            switch step {
            case .details: return "Sending code…"
            case .verification: return "Verifying email…"
            case .password, .profile: return "Finishing account…"
            case .complete: return "Done"
            }
        }
        switch step {
        case .details: return "Send verification code"
        case .verification: return isEmailVerified ? "Continue" : "Verify email"
        case .password: return "Create account"
        case .profile: return "Finish account setup"
        case .complete: return "Done"
        }
    }

    var stepNumber: Int {
        switch step {
        case .details: return 1
        case .verification: return 2
        case .password, .profile, .complete: return 3
        }
    }

    func validationMessage(for field: Field) -> String? {
        guard touchedFields.contains(field) else { return nil }
        switch field {
        case .email:
            return EmailCredentialValidator.isValidEmail(email) ? nil : "Enter a valid email address."
        case .code:
            return EmailCredentialValidator.isValidCode(code) ? nil : "Enter the six-digit code from your email."
        case .password:
            return EmailCredentialValidator.isValidPassword(password) ? nil : "Use at least 6 characters."
        case .displayName:
            return nil
        }
    }

    func onFieldEndedEditing(_ field: Field?) {
        guard let field else { return }
        touchedFields.insert(field)
    }

    func onFieldValueChanged(_ value: String, for field: Field) {
        guard !isBusy else { return }
        errorMessage = nil
        offersSignIn = false
        switch field {
        case .email: email = value
        case .displayName: displayName = value
        case .password: password = value
        case .code: code = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
        }
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.appear)
        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            displayName = interactor.suggestedDisplayName ?? ""
        }
    }

    func onFirstTask() async {
        guard !isBusy, step != .complete else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            applyPending(try await interactor.restoreEmailRegistration())
        } catch {
            handleFailure(error)
        }
    }

    func updateResendCountdown(isActive: Bool) async {
        guard isActive else { return }
        while !Task.isCancelled {
            resendSecondsRemaining = interactor.pendingEmailRegistration?.resendSecondsRemaining(at: .now) ?? 0
            do { try await Task.sleep(for: .seconds(1)) } catch { return }
        }
    }

    func onViewDisappear() {
        password = ""
        code = ""
        interactor.trackEvent(event: Event.disappear)
    }

    func onClosePressed() {
        guard !isBusy else { return }
        password = ""
        code = ""
        interactor.trackEvent(event: Event.action("Close"))
        router.dismissScreen()
    }

    func onBackPressed() {
        guard !isBusy, canGoBack else { return }
        interactor.trackEvent(event: Event.action("Back"))
        step = step == .password ? .verification : .details
        errorMessage = nil
        code = ""
    }

    func onTogglePasswordPressed() {
        guard !isBusy else { return }
        isPasswordVisible.toggle()
    }

    func onSignInPressed(delegate: SignUpDelegate) {
        guard !isBusy else { return }
        interactor.trackEvent(event: Event.action("SignIn"))
        router.showSignInView(
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            onDidSignIn: delegate.onDidSignInToExistingAccount ?? delegate.onDidSignIn
        )
    }

    func onResendPressed() {
        guard !isBusy, step == .verification, !isEmailVerified, resendSecondsRemaining == 0 else { return }
        isSubmitting = true
        errorMessage = nil
        interactor.trackEvent(event: Event.action("Resend"))
        submissionTask = Task {
            defer {
                isSubmitting = false
                submissionTask = nil
            }
            do {
                applyPending(try await interactor.resendEmailRegistrationCode())
                code = ""
            } catch {
                handleFailure(error)
            }
        }
    }

    func onSubmitPressed(delegate: SignUpDelegate) {
        guard canSubmit else { return }
        if step == .complete {
            onClosePressed()
            return
        }
        let submittedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedName = displayName
        let submittedCode = code
        let submittedPassword = password
        let submittedStep = step
        let emailWasVerified = isEmailVerified
        isSubmitting = true
        errorMessage = nil
        offersSignIn = false
        interactor.trackEvent(event: Event.action("Submit_\(step.rawValue)"))
        submissionTask = Task {
            defer {
                isSubmitting = false
                submissionTask = nil
            }
            do {
                switch submittedStep {
                case .details:
                    applyPending(try await interactor.beginEmailRegistration(email: submittedEmail, displayName: submittedName))
                case .verification:
                    if emailWasVerified {
                        step = .password
                    } else {
                        applyPending(try await interactor.verifyEmailRegistrationCode(submittedCode))
                        code = ""
                    }
                case .password, .profile:
                    try await interactor.finishEmailRegistration(password: submittedPassword)
                    password = ""
                    code = ""
                    step = .complete
                    interactor.trackEvent(event: Event.action("Success"))
                    delegate.onDidSignIn?()
                case .complete:
                    break
                }
            } catch {
                handleFailure(error)
            }
        }
    }

    private func applyPending(_ pending: PendingEmailRegistration?) {
        guard let pending else { return }
        email = pending.email
        displayName = pending.displayName ?? ""
        step = Step(rawValue: pending.stage.rawValue) ?? .details
        resendSecondsRemaining = pending.resendSecondsRemaining(at: .now)
    }

    private func handleFailure(_ error: Error) {
        applyPending(interactor.pendingEmailRegistration)
        let authError = error as? EmailAuthError
        offersSignIn = authError == .emailAlreadyInUse
        isUnavailable = authError == .notConfigured
        if authError == .sessionChanged {
            step = .details
            password = ""
            code = ""
        }
        errorMessage = authError?.errorDescription
            ?? (step == .profile
                ? "Your password is saved. We couldn't finish setup on this device. Tap Finish account setup to retry."
                : "Couldn't complete this step. Check your connection and try again.")
        interactor.trackEvent(event: Event.failure)
    }
}

extension SignUpPresenter {
    enum Event: LoggableEvent {
        case appear, disappear, failure
        case action(String)

        var eventName: String {
            switch self {
            case .appear: return "SignUpView_Appear"
            case .disappear: return "SignUpView_Disappear"
            case .failure: return "SignUpView_Fail"
            case .action(let action): return "SignUpView_\(action)"
            }
        }

        var parameters: [String: Any]? { nil }
        var type: LogType {
            if case .failure = self { return .warning }
            return .analytic
        }
    }
}
