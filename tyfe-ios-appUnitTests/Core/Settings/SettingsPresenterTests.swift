import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SettingsPresenterTests {
    @Test func completedAccountsOpenEditorButGuestsPendingAndSignedOutOpenAccountSetup() {
        let interactor = ProfileSettingsTestInteractor()
        let router = ProfileSettingsTestRouter()
        let presenter = SettingsPresenter(interactor: interactor, router: router)
        presenter.onProfilePressed()
        #expect(router.profileCount == 1)
        #expect(router.accountSetupCount == 0)

        interactor.pendingEmailRegistration = PendingEmailRegistration(userId: "account", email: "pending@example.com", displayName: "Pending", stage: .password)
        #expect(presenter.accountActionTitle == "Finish creating account")
        #expect(presenter.email == "pending@example.com")
        presenter.onProfilePressed()
        interactor.pendingEmailRegistration = nil
        interactor.auth = .mock(isAnonymous: true)
        presenter.onProfilePressed()
        interactor.auth = nil
        presenter.onProfilePressed()
        #expect(router.profileCount == 1)
        #expect(router.accountSetupCount == 3)
        #expect(presenter.accountActionTitle == "Create account")
    }

    @Test func preferredCachedNameWinsAndAnotherAccountsCacheNeverLeaksIntoIdentity() {
        let interactor = ProfileSettingsTestInteractor()
        let presenter = SettingsPresenter(interactor: interactor, router: ProfileSettingsTestRouter())
        #expect(presenter.displayName == "Ada Lovelace")
        #expect(presenter.initials == "AL")
        interactor.currentUser = UserModel(userId: "another-account", email: "other@example.com", submittedName: "Other Person")
        interactor.profilePhotoURL = URL(string: "https://example.com/other-account-avatar")
        #expect(presenter.displayName == "Auth name")
        #expect(presenter.email == "ada@example.com")
        #expect(presenter.photoURL == nil)
        interactor.auth = nil
        #expect(presenter.displayName == "Not signed in")
        #expect(presenter.email == nil)
    }
}
