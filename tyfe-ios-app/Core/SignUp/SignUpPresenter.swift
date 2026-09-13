//
//  SignUpPresenter.swift
//  tyfe-ios-app
//

import SwiftUI

@Observable
@MainActor
final class SignUpPresenter {

    private let interactor: SignUpInteractor
    private let router: SignUpRouter

    var email = ""
    var password = ""
    var displayName = ""
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    init(interactor: SignUpInteractor, router: SignUpRouter) {
        self.interactor = interactor
        self.router = router
    }

    var canSubmit: Bool {
        !isSubmitting
            && EmailCredentialValidator.isValidEmail(email)
            && EmailCredentialValidator.isValidPassword(password)
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        prefillDisplayNameIfNeeded()
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onClosePressed() {
        router.dismissScreen()
    }

    func onSignInPressed(delegate: SignUpDelegate) {
        interactor.trackEvent(event: Event.signInPressed)
        router.showSignInView(onDidSignIn: delegate.onDidSignIn)
    }

    func onSubmitPressed(delegate: SignUpDelegate) {
        guard canSubmit else { return }

        errorMessage = nil
        isSubmitting = true
        interactor.trackEvent(event: Event.submit)

        Task {
            do {
                let result = try await interactor.registerWithEmail(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password,
                    displayName: displayName
                )
                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)

                isSubmitting = false
                interactor.trackEvent(event: Event.success(user: result.user, isNewUser: result.isNewUser))
                delegate.onDidSignIn?()
                router.dismissScreen()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                interactor.trackEvent(event: Event.fail(error: error))
            }
        }
    }

    private func prefillDisplayNameIfNeeded() {
        guard displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let suggested = interactor.suggestedDisplayName else { return }
        displayName = suggested
    }
}

extension SignUpPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case signInPressed
        case submit
        case success(user: UserAuthInfo, isNewUser: Bool)
        case fail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:      return "SignUpView_Appear"
            case .onDisappear:   return "SignUpView_Disappear"
            case .signInPressed: return "SignUpView_SignInPressed"
            case .submit:        return "SignUpView_Submit"
            case .success:       return "SignUpView_Success"
            case .fail:          return "SignUpView_Fail"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .success(user: let user, isNewUser: let isNewUser):
                var dict = user.eventParameters
                dict["is_new_user"] = isNewUser
                return dict
            case .fail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .fail:
                return .severe
            default:
                return .analytic
            }
        }
    }
}
