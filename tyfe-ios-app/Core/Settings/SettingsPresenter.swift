import SwiftUI
import SwiftfulUtilities

@Observable
@MainActor
final class SettingsPresenter {

    private let interactor: SettingsInteractor
    private let router: SettingsRouter

    var isAnonymousUser: Bool { interactor.auth?.isAnonymous == true }
    var isSignedIn: Bool { interactor.currentAuthUserId != nil }
    var needsAccountSetup: Bool { !interactor.canEditProfile }
    var canEditProfile: Bool { interactor.canEditProfile }
    var isDarkMode: Bool { interactor.colorScheme == .dark }

    private var matchingUser: UserModel? {
        guard interactor.currentUser?.userId == currentUserId else { return nil }
        return interactor.currentUser
    }

    var displayName: String {
        ProfileDisplayIdentity.name(user: matchingUser, auth: interactor.auth)
            ?? interactor.pendingEmailRegistration?.displayName
            ?? accountTitle
    }

    var email: String? {
        interactor.pendingEmailRegistration?.email ?? interactor.auth?.email ?? matchingUser?.emailCalculated
    }

    var initials: String { ProfileDisplayIdentity.initials(name: displayName) }
    var photoURL: URL? { canEditProfile && matchingUser != nil ? interactor.profilePhotoURL : nil }
    var accountActionTitle: String {
        if canEditProfile { return "Edit profile" }
        return interactor.pendingEmailRegistration == nil ? "Create account" : "Finish creating account"
    }

    func onDarkModeChanged(_ enabled: Bool) {
        interactor.setDarkMode(enabled)
    }

    func onProfilePressed() {
        guard canEditProfile else {
            onSaveAccountPressed()
            return
        }
        router.showProfileView(delegate: ProfileDelegate())
    }

    init(interactor: SettingsInteractor, router: SettingsRouter) {
        self.interactor = interactor
        self.router = router
    }

    var currentUserId: String? {
        interactor.currentAuthUserId
    }

    var accountTitle: String {
        if interactor.pendingEmailRegistration != nil { return "Finish creating your account" }
        guard isSignedIn else { return "Not signed in" }
        return isAnonymousUser ? "Guest account" : "Signed in"
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.onAppear)
        Task { await refreshProfile() }
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.onDisappear)
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
                returnToWelcome()
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
                returnToWelcome()
            } catch {
                router.showAlert(error: error)
                interactor.trackEvent(event: Event.deleteAccountFail(error: error))
            }
        }
    }

    func onSaveAccountPressed() {
        interactor.trackEvent(event: Event.saveAccountPressed)

        router.showSignUpView(delegate: SignUpDelegate(onDidSignIn: { [weak self] in
            self?.onAccountSetupCompleted()
        }))
    }

    private func onAccountSetupCompleted() {
        interactor.trackEvent(eventName: "SettingsView_AccountSetupCompleted", parameters: nil, type: .analytic)
        Task { await refreshProfile() }
    }

    // MARK: Private

    private func refreshProfile() async {
        guard canEditProfile else { return }
        // Cached identity remains useful when the network is unavailable.
        try? await interactor.refreshProfile()
    }

    private func returnToWelcome() {
        router.switchToWelcome()
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
        case saveAccountPressed
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
            case .saveAccountPressed:          return "SettingsView_SaveAccount_Pressed"
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
