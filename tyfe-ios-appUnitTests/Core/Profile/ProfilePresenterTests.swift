import Foundation
import SwiftUI
import SwiftfulRouting
import Testing
@testable import tyfe_ios_app

@MainActor
struct ProfilePresenterTests {
    @Test func saveRequiresChangedValidDraftAndBlocksDuplicateWrites() async {
        let interactor = ProfileSettingsTestInteractor()
        let router = ProfileSettingsTestRouter()
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        #expect(!presenter.canSave)
        presenter.onNameChanged("Changed while loading")
        #expect(presenter.name == "Ada Lovelace")
        await presenter.onFirstTask()
        #expect(!presenter.canSave)
        presenter.onNameChanged("  Ada Lovelace \n")
        #expect(!presenter.canSave)
        presenter.onNameChanged("   ")
        #expect(!presenter.canSave)
        presenter.onNameChanged(String(repeating: "A", count: 61))
        #expect(!presenter.canSave)
        presenter.onNameChanged("  Grace Hopper \n")
        #expect(presenter.canSave)
        presenter.onSavePressed()
        presenter.onSavePressed()
        presenter.onNameChanged("Cannot change during save")
        presenter.onCancelPressed()
        #expect(!presenter.canSave)
        #expect(presenter.name == "  Grace Hopper \n")
        #expect(router.dismissCount == 0)
        await presenter.saveTask?.value
        #expect(interactor.savedDrafts.count == 1)
        #expect(interactor.savedDrafts.first?.name == "Grace Hopper")
        #expect(router.dismissCount == 1)
    }

    @Test func failedSaveRetainsNameAndPhotoRemovalForRetry() async {
        let interactor = ProfileSettingsTestInteractor(avatarPath: "account/old.jpg")
        interactor.saveFailuresRemaining = 1
        let router = ProfileSettingsTestRouter()
        var completions = 0
        let presenter = ProfilePresenter(interactor: interactor, router: router, delegate: ProfileDelegate(onDidSave: { completions += 1 }))
        await presenter.onFirstTask()
        presenter.onNameChanged("Grace")
        presenter.onRemovePhotoPressed()
        presenter.onSavePressed()
        await presenter.saveTask?.value
        #expect(presenter.name == "Grace")
        #expect(presenter.photoChange == .remove)
        #expect(presenter.errorMessage != nil)
        #expect(presenter.canSave)
        #expect(router.dismissCount == 0)
        #expect(completions == 0)
        await presenter.onRetryPressed()
        await presenter.saveTask?.value
        #expect(interactor.savedDrafts.last?.name == "Grace")
        #expect(interactor.savedDrafts.last?.photo == .remove)
        #expect(router.dismissCount == 1)
        #expect(completions == 1)
    }

    @Test func cancelRequiresExplicitDiscardAndNeverWrites() async {
        let interactor = ProfileSettingsTestInteractor()
        let router = ProfileSettingsTestRouter()
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        await presenter.onFirstTask()
        presenter.onNameChanged("Draft")
        presenter.onCancelPressed()
        #expect(presenter.showsDiscardConfirmation)
        #expect(router.dismissCount == 0)
        presenter.onKeepEditingPressed()
        #expect(!presenter.showsDiscardConfirmation)
        #expect(presenter.name == "Draft")
        presenter.onCancelPressed()
        presenter.onDiscardConfirmed()
        #expect(router.dismissCount == 1)
        #expect(interactor.savedDrafts.isEmpty)
    }

    @Test func refreshFailureUsesCacheAndRetryPreservesAnEditedDraft() async {
        let interactor = ProfileSettingsTestInteractor()
        interactor.refreshFailuresRemaining = 1
        let presenter = ProfilePresenter(interactor: interactor, router: ProfileSettingsTestRouter())
        await presenter.onFirstTask()
        #expect(presenter.name == "Ada Lovelace")
        #expect(presenter.errorMessage != nil)
        presenter.onNameChanged("Unsaved name")
        interactor.afterRefresh = {
            interactor.currentUser = UserModel(userId: "account", submittedName: "Server name")
        }
        await presenter.onRetryPressed()
        #expect(presenter.name == "Unsaved name")
        #expect(presenter.canSave)
        #expect(presenter.errorMessage == nil)
    }

    @Test func accountAndSessionChangesCannotSaveOrCompleteAnOldDraft() async {
        let interactor = ProfileSettingsTestInteractor()
        let router = ProfileSettingsTestRouter()
        var completions = 0
        let presenter = ProfilePresenter(interactor: interactor, router: router, delegate: ProfileDelegate(onDidSave: { completions += 1 }))
        await presenter.onFirstTask()
        presenter.onNameChanged("Old session draft")
        interactor.auth = ProfileSettingsTestInteractor.accountAuth(signInDate: Date(timeIntervalSince1970: 200))
        presenter.onSavePressed()
        #expect(!presenter.canSave)
        #expect(interactor.savedDrafts.isEmpty)
        #expect(presenter.accountMessage != nil)

        let fresh = ProfilePresenter(interactor: interactor, router: router, delegate: ProfileDelegate(onDidSave: { completions += 1 }))
        await fresh.onFirstTask()
        fresh.onNameChanged("In flight")
        var continuation: CheckedContinuation<Void, Never>?
        interactor.beforeSave = { await withCheckedContinuation { continuation = $0 } }
        fresh.onSavePressed()
        while continuation == nil { await Task.yield() }
        interactor.auth = nil
        continuation?.resume()
        await fresh.saveTask?.value
        #expect(router.dismissCount == 0)
        #expect(completions == 0)
        #expect(!fresh.canSave)
    }

    @Test func sameUIDAndTimestampCannotReuseADraftAcrossSessionGeneration() async {
        let interactor = ProfileSettingsTestInteractor(avatarPath: "account/photo.jpg")
        let router = ProfileSettingsTestRouter()
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        await presenter.onFirstTask()
        presenter.onNameChanged("Old private draft")
        presenter.onRemovePhotoPressed()
        interactor.profileSessionGeneration += 1
        presenter.onSavePressed()
        #expect(interactor.savedDrafts.isEmpty)
        #expect(!presenter.canSave)
        #expect(presenter.name.isEmpty)
        #expect(presenter.email == nil)
        #expect(presenter.photoChange == .unchanged)
        #expect(presenter.draftPhoto == nil)
        #expect(presenter.accountMessage != nil)
        presenter.onCancelPressed()
        #expect(router.dismissCount == 1)
    }

    @Test func photoDraftCommitsOnlyAfterCropAndSurvivesCancellingAnotherCrop() async throws {
        let interactor = ProfileSettingsTestInteractor()
        let router = ProfileSettingsTestRouter()
        let presenter = ProfilePresenter(interactor: interactor, router: router)
        await presenter.onFirstTask()
        let source = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 80)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 80))
        }
        let png = try #require(source.pngData())
        try presenter.onPhotoDataLoaded(png)
        #expect(!presenter.canSave)
        #expect(presenter.photoChange == .unchanged)
        presenter.onCropChanged(zoom: 2, offset: CGSize(width: 20, height: -20))
        presenter.onUsePhotoPressed()
        guard case .replace(let firstJPEG) = presenter.photoChange else {
            Issue.record("The crop should produce a replacement photo")
            return
        }
        #expect(presenter.canSave)
        #expect(presenter.draftPhoto?.size == CGSize(width: 512, height: 512))
        try presenter.onPhotoDataLoaded(png)
        presenter.onCancelCropPressed()
        #expect(presenter.photoChange == .replace(firstJPEG))
        #expect(presenter.canSave)
        presenter.onRemovePhotoPressed()
        #expect(presenter.photoChange == .unchanged)
        #expect(!presenter.canSave)
        #expect(interactor.savedDrafts.isEmpty)
    }
}

@MainActor
final class ProfileSettingsTestInteractor: ProfileInteractor, SettingsInteractor {
    var auth: UserAuthInfo? = accountAuth()
    var currentUser: UserModel?
    var profilePhotoURL: URL?
    var profileSessionGeneration = 0
    var pendingEmailRegistration: PendingEmailRegistration?
    var currentAuthUserId: String? { auth?.uid }
    var canEditProfile: Bool { auth?.isAnonymous == false && pendingEmailRegistration == nil }
    var colorScheme: ColorScheme = .light
    var refreshFailuresRemaining = 0
    var saveFailuresRemaining = 0
    var afterRefresh: (() -> Void)?
    var beforeSave: (() async -> Void)?
    var savedDrafts: [(name: String, photo: ProfilePhotoChange)] = []

    init(avatarPath: String? = nil) {
        currentUser = UserModel(userId: "account", email: "ada@example.com", displayName: "Auth name", submittedName: "Ada Lovelace", avatarPath: avatarPath)
    }

    static func accountAuth(signInDate: Date = Date(timeIntervalSince1970: 100)) -> UserAuthInfo {
        UserAuthInfo(uid: "account", email: "ada@example.com", isAnonymous: false, authProviders: [.email], displayName: "Auth name", lastSignInDate: signInDate)
    }

    func refreshProfile() async throws {
        if refreshFailuresRemaining > 0 {
            refreshFailuresRemaining -= 1
            throw URLError(.notConnectedToInternet)
        }
        afterRefresh?()
    }
    func saveProfile(name: String, photo: ProfilePhotoChange) async throws {
        await beforeSave?()
        savedDrafts.append((name, photo))
        if saveFailuresRemaining > 0 {
            saveFailuresRemaining -= 1
            throw URLError(.cannotConnectToHost)
        }
    }
    func setDarkMode(_ enabled: Bool) { colorScheme = enabled ? .dark : .light }
    func signOut() async throws { auth = nil }
    func deleteAccount() async throws { auth = nil }
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
final class ProfileSettingsTestRouter: ProfileRouter, SettingsRouter {
    var router: AnyRouter { fatalError("Navigation storage is not used by this test double") }
    var dismissCount = 0
    var profileCount = 0
    var accountSetupCount = 0
    func dismissScreen() { dismissCount += 1 }
    func showProfileView(delegate: ProfileDelegate) { profileCount += 1 }
    func showSignUpView(delegate: SignUpDelegate) { accountSetupCount += 1 }
    func switchToWelcome() {}
}
