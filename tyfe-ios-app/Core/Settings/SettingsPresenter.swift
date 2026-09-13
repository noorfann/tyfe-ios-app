import SwiftUI
import SwiftfulUtilities

@Observable
@MainActor
final class SettingsPresenter {

    private let interactor: SettingsInteractor
    private let router: SettingsRouter

    private(set) var isPremium = false
    private(set) var isAnonymousUser = false
    private(set) var isSignedIn = false
    private(set) var cheersToday = 0

    init(interactor: SettingsInteractor, router: SettingsRouter) {
        self.interactor = interactor
        self.router = router
    }

    var currentUserId: String? {
        interactor.currentAuthUserId
    }

    var accountTitle: String {
        guard isSignedIn else { return "Not signed in" }
        return isAnonymousUser ? "Signed in anonymously" : "Signed in"
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        isPremium = interactor.isPremium
        setAnonymousAccountStatus()
        isSignedIn = interactor.currentAuthUserId != nil
        Task { await refreshSocialState() }
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
    }

    func setAnonymousAccountStatus() {
        isAnonymousUser = interactor.auth?.isAnonymous == true
    }

    func onContactUsPressed() {
        interactor.trackEvent(event: Event.contactUsPressed)
        let email = "hello@swiftful-thinking.com"
        let emailString = "mailto:\(email)"

        guard let url = URL(string: emailString), UIApplication.shared.canOpenURL(url) else {
            return
        }

        UIApplication.shared.open(url)
    }

    func onSignOutPressed() {
        interactor.trackEvent(event: Event.signOutStart)

        Task {
            do {
                try await interactor.signOut()
                interactor.trackEvent(event: Event.signOutSuccess)
                returnToOnboarding()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.signOutFail(error: error))
            }
        }
    }

    func onDeleteAccountPressed() {
        interactor.trackEvent(event: Event.deleteAccountStart)

        router.showAlert(
            .alert,
            title: "Delete Account?",
            subtitle: "This action is permanent and cannot be undone. Your data will be deleted from our server forever.",
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive, action: {
                        self.showDeleteAccountReauthAlert()
                    })
                )
            }
        )
    }

    private func showDeleteAccountReauthAlert() {
        router.showAlert(
            .alert,
            title: "Reauthentication Required",
            subtitle: "As a safety precaution in order to delete your account, you must first sign again.",
            buttons: {
                AnyView(
                    Button("Delete", role: .destructive, action: {
                        self.onDeleteAccountConfirmed()
                    })
                )
            }
        )
    }

    private func onDeleteAccountConfirmed() {
        interactor.trackEvent(event: Event.deleteAccountStartConfirm)

        Task {
            do {
                try await interactor.deleteAccount()
                interactor.trackEvent(event: Event.deleteAccountSuccess)
                returnToOnboarding()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.deleteAccountFail(error: error))
            }
        }
    }

    func onCreateAccountPressed() {
        interactor.trackEvent(event: Event.createAccountPressed)

        let delegate = CreateAccountDelegate()
        router.showCreateAccountView(delegate: delegate, onDismiss: {
            self.setAnonymousAccountStatus()
        })
    }

    // MARK: Private

    private func refreshSocialState() async {
        guard interactor.currentAuthUserId != nil else {
            cheersToday = 0
            return
        }
        do {
            try await interactor.refreshSocialCheers()
            cheersToday = interactor.socialCheers.count
        } catch {
            // Account settings stay usable when social stats cannot load.
        }
    }

    private func returnToOnboarding() {
        router.switchToOnboardingModule()
    }

}

extension SettingsPresenter {

    enum Event: LoggableEvent {
        case onAppear
        case onDisappear
        case signOutStart
        case signOutSuccess
        case signOutFail(error: Error)
        case deleteAccountStart
        case deleteAccountStartConfirm
        case deleteAccountSuccess
        case deleteAccountFail(error: Error)
        case createAccountPressed
        case contactUsPressed

        var eventName: String {
            switch self {
            case .onAppear:                     return "SettingsView_Appear"
            case .onDisappear:                  return "SettingsView_Disappear"
            case .signOutStart:                 return "SettingsView_SignOut_Start"
            case .signOutSuccess:               return "SettingsView_SignOut_Success"
            case .signOutFail:                  return "SettingsView_SignOut_Fail"
            case .deleteAccountStart:           return "SettingsView_DeleteAccount_Start"
            case .deleteAccountStartConfirm:    return "SettingsView_DeleteAccount_StartConfirm"
            case .deleteAccountSuccess:         return "SettingsView_DeleteAccount_Success"
            case .deleteAccountFail:            return "SettingsView_DeleteAccount_Fail"
            case .createAccountPressed:         return "SettingsView_CreateAccount_Pressed"
            case .contactUsPressed:             return "SettingsView_ContactUs_Pressed"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .signOutFail(error: let error), .deleteAccountFail(error: let error):
                return error.eventParameters
            default:
                return nil
            }
        }

        var type: LogType {
            switch self {
            case .signOutFail, .deleteAccountFail:
                return .severe
            default:
                return .analytic
            }
        }
    }

}
