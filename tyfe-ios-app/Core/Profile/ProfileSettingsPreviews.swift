#if DEBUG
import SwiftUI
import SwiftfulUI

#Preview("Settings · Photo") { ProfileSettingsPreview.settings(photo: true) }
#Preview("Settings · Light · Initials") { ProfileSettingsPreview.settings() }
#Preview("Settings · Dark") { ProfileSettingsPreview.settings(dark: true) }
#Preview("Settings · Signed out") { ProfileSettingsPreview.settings(account: .signedOut) }
#Preview("Settings · Guest") { ProfileSettingsPreview.settings(account: .guest) }
#Preview("Settings · Pending account") { ProfileSettingsPreview.settings(account: .pending) }
#Preview("Settings · Long email") { ProfileSettingsPreview.settings(longEmail: true) }
#Preview("Settings · Large type") {
    ProfileSettingsPreview.settings(longEmail: true).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Profile · Light · Initials") { ProfileSettingsPreview.profile() }
#Preview("Profile · Dark") { ProfileSettingsPreview.profile(dark: true) }
#Preview("Profile · Photo draft") { ProfileSettingsPreview.profile(photo: true) }
#Preview("Profile · Long email · Large type") {
    ProfileSettingsPreview.profile(longEmail: true).environment(\.dynamicTypeSize, .accessibility3)
}
#Preview("Profile · Signed URL failed · Initials") { ProfileSettingsPreview.profile(failedPhoto: true) }
#Preview("Crop · Manual positioning") { ProfileSettingsPreview.crop() }

@MainActor
private enum ProfileSettingsPreview {
    enum Account { case complete, signedOut, guest, pending }

    static func settings(account: Account = .complete, dark: Bool = false, longEmail: Bool = false, photo: Bool = false) -> some View {
        let interactor = PreviewInteractor(account: account, dark: dark, longEmail: longEmail)
        if photo { interactor.profilePhotoURL = samplePhotoURL() }
        return RouterView { router in
            SettingsView(presenter: SettingsPresenter(
                interactor: interactor, router: PreviewRouter(router: router, interactor: interactor)
            ))
        }
        .preferredColorScheme(dark ? .dark : .light)
    }

    static func profile(dark: Bool = false, longEmail: Bool = false, photo: Bool = false, failedPhoto: Bool = false) -> some View {
        let interactor = PreviewInteractor(dark: dark, longEmail: longEmail)
        if failedPhoto { interactor.profilePhotoURL = URL(fileURLWithPath: "/missing/expired-avatar.jpg") }
        return RouterView { router in
            let presenter = ProfilePresenter(interactor: interactor, router: PreviewRouter(router: router, interactor: interactor))
            return ProfileView(presenter: presenter)
                .task {
                    if photo {
                        await presenter.onFirstTask()
                        if let data = samplePhoto().pngData() {
                            try? presenter.onPhotoDataLoaded(data)
                            presenter.onUsePhotoPressed()
                        }
                    }
                }
        }
        .preferredColorScheme(dark ? .dark : .light)
    }

    static func crop() -> some View {
        let interactor = PreviewInteractor()
        return RouterView { router in
            let presenter = ProfilePresenter(interactor: interactor, router: PreviewRouter(router: router, interactor: interactor))
            return ProfileCropEditor(presenter: presenter)
                .task {
                    await presenter.onFirstTask()
                    if let data = samplePhoto().pngData() { try? presenter.onPhotoDataLoaded(data) }
                }
        }
    }

    static func samplePhotoURL() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("preview-profile-\(UUID().uuidString).jpg")
        guard let jpeg = samplePhoto().jpegData(compressionQuality: 0.9) else { return nil }
        do {
            try jpeg.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }

    static func samplePhoto() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 500, height: 700)).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 500, height: 700))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 80, y: 180, width: 280, height: 280))
            UIColor.systemOrange.setFill()
            context.fill(CGRect(x: 240, y: 320, width: 180, height: 220))
        }
    }

    @Observable
    final class PreviewInteractor: SettingsInteractor, ProfileInteractor {
        var auth: UserAuthInfo?
        var currentUser: UserModel?
        var profilePhotoURL: URL?
        var profileSessionGeneration = 0
        var pendingEmailRegistration: PendingEmailRegistration?
        var colorScheme: ColorScheme
        var currentAuthUserId: String? { auth?.uid }
        var canEditProfile: Bool { auth?.isAnonymous == false && pendingEmailRegistration == nil }

        init(account: Account = .complete, dark: Bool = false, longEmail: Bool = false) {
            colorScheme = dark ? .dark : .light
            let email = longEmail ? "a.very.long.email.address.for.accessibility.and.wrapping@example.com" : "ada@example.com"
            if account != .signedOut {
                auth = UserAuthInfo(uid: "preview-user", email: email, isAnonymous: account == .guest, authProviders: [.email], displayName: "Auth name")
                currentUser = UserModel(userId: "preview-user", email: email, submittedName: "Ada Lovelace")
            }
            if account == .pending {
                pendingEmailRegistration = PendingEmailRegistration(userId: "preview-user", email: email, displayName: "Ada Lovelace", stage: .password)
            }
        }

        func setDarkMode(_ enabled: Bool) { colorScheme = enabled ? .dark : .light }
        func refreshProfile() async throws {}
        func saveProfile(name: String, photo: ProfilePhotoChange) async throws {
            currentUser = UserModel(userId: "preview-user", email: auth?.email, submittedName: name)
        }
        func signOut() async throws { auth = nil; currentUser = nil; profilePhotoURL = nil }
        func deleteAccount() async throws { try await signOut() }
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

    struct PreviewRouter: SettingsRouter, ProfileRouter {
        let router: AnyRouter
        let interactor: PreviewInteractor
        func showProfileView(delegate: ProfileDelegate) {
            router.showScreen(.push) { router in
                ProfileView(presenter: ProfilePresenter(
                    interactor: interactor,
                    router: PreviewRouter(router: router, interactor: interactor),
                    delegate: delegate
                ))
            }
        }
        func showSignUpView(delegate: SignUpDelegate) {}
        func switchToWelcome() { router.dismissPushStack() }
    }
}
#endif
