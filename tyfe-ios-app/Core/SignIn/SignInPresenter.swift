//
//  SignInPresenter.swift
//  tyfe-ios-app
//

import SwiftUI

@Observable
@MainActor
final class SignInPresenter {

    private let interactor: SignInInteractor
    private let router: SignInRouter

    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var errorMessage: String?

    init(interactor: SignInInteractor, router: SignInRouter) {
        self.interactor = interactor
        self.router = router
    }

    var canSubmit: Bool {
        !isSubmitting
            && EmailCredentialValidator.isValidEmail(email)
            && !password.isEmpty
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func onBackPressed() {
        router.dismissScreen()
    }

    func onSubmitPressed(delegate: SignInDelegate) {
        guard canSubmit else { return }

        errorMessage = nil
        isSubmitting = true
        interactor.trackEvent(event: Event.submit)

        Task {
            do {
                let result = try await interactor.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
                try await interactor.logIn(user: result.user, isNewUser: result.isNewUser)

                isSubmitting = false
                interactor.trackEvent(event: Event.success(user: result.user, isNewUser: result.isNewUser))
                delegate.onDidSignIn?()
                router.dismissEnvironment()
            } catch {
                isSubmitting = false
                errorMessage = error.localizedDescription
                interactor.trackEvent(event: Event.fail(error: error))
            }
        }
    }
}

extension SignInPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case submit
        case success(user: UserAuthInfo, isNewUser: Bool)
        case fail(error: Error)

        var eventName: String {
            switch self {
            case .onAppear:    return "SignInView_Appear"
            case .onDisappear: return "SignInView_Disappear"
            case .submit:      return "SignInView_Submit"
            case .success:     return "SignInView_Success"
            case .fail:        return "SignInView_Fail"
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
