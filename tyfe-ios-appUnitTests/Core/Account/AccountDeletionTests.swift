import Foundation
import SwiftfulDataManagers
import Testing
@testable import tyfe_ios_app

@MainActor
struct AccountDeletionTests {
    @Test func storageAndRemoteFailuresKeepDeletionRetryable() async throws {
        let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
        let user = UserAuthInfo(uid: "deletion-owner", email: "owner@example.com", isAnonymous: false, authProviders: [.email])
        let photos = DeletionPhotoService(userId: user.uid)
        let authService = DeletionAuthService(user: user, photos: photos)
        let authManager = AuthManager(service: authService)
        let manager = UserManager(
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: nil),
                managerKey: UserManager.persistenceKey,
                enableLocalPersistence: false
            ),
            profileService: photos
        )
        try await manager.signIn(auth: user, isNewUser: false)
        dependencies.container.register(AuthManager.self, service: authManager)
        dependencies.container.register(UserManager.self, service: manager)
        let interactor = CoreInteractor(container: dependencies.container)

        photos.failCleanup = true
        await #expect(throws: DeletionFailure.storage) { try await interactor.deleteAccount() }
        #expect(photos.ownedPaths == ["deletion-owner/photo.jpg"])
        #expect(interactor.auth?.uid == user.uid)
        #expect(interactor.currentUser?.commonNameCalculated == "Owner")
        #expect(authService.accountExists)

        photos.failCleanup = false
        authService.failRemoteDelete = true
        await #expect(throws: DeletionFailure.remote) { try await interactor.deleteAccount() }
        #expect(photos.ownedPaths.isEmpty)
        #expect(interactor.auth?.uid == user.uid)
        #expect(interactor.currentUser?.userId == user.uid)
        #expect(authService.accountExists)

        authService.failRemoteDelete = false
        try await interactor.deleteAccount()
        #expect(!authService.accountExists)
        #expect(interactor.auth == nil)
        #expect(manager.currentUser == nil)
        #expect(manager.profilePhotoURL == nil)
        #expect(interactor.entryPhase == .welcome)
    }
}

private enum DeletionFailure: Error, Equatable {
    case storage
    case remote
    case photosRemain
}

@MainActor
private final class DeletionPhotoService: ProfileServicing {
    let userId: String
    var ownedPaths: Set<String> = ["deletion-owner/photo.jpg"]
    var failCleanup = false

    init(userId: String) { self.userId = userId }

    func fetchProfile(userId: String) async throws -> ProfileIdentity {
        ProfileIdentity(userId: userId, displayName: "Owner")
    }

    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity {
        ProfileIdentity(userId: userId, displayName: name, avatarPath: avatarPath)
    }

    func uploadPhoto(userId: String, jpeg: Data) async throws -> String { throw ProfileServiceError.unavailable }
    func resolvePhotoURL(path: String) async throws -> URL { throw ProfileServiceError.unavailable }
    func removePhoto(path: String) async throws { ownedPaths.remove(path) }

    func removeAllPhotos(userId: String) async throws {
        guard userId == self.userId else { throw ProfileServiceError.accountChanged }
        if failCleanup { throw DeletionFailure.storage }
        ownedPaths.removeAll()
    }
}

@MainActor
private final class DeletionAuthService: AuthService {
    private var user: UserAuthInfo?
    private let photos: DeletionPhotoService
    var failRemoteDelete = false
    private(set) var accountExists = true

    init(user: UserAuthInfo, photos: DeletionPhotoService) {
        self.user = user
        self.photos = photos
    }

    func getAuthenticatedUser() -> UserAuthInfo? { user }
    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> { AsyncStream { $0.finish() } }
    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        guard let user else { throw ProfileServiceError.accountChanged }
        return (user, false)
    }
    func signOut() throws { user = nil }

    func deleteAccount() async throws {
        guard photos.ownedPaths.isEmpty else { throw DeletionFailure.photosRemain }
        if failRemoteDelete { throw DeletionFailure.remote }
        accountExists = false
        user = nil
    }

    func deleteAccountWithReauthentication(
        option: SignInOption,
        revokeToken: Bool,
        performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void
    ) async throws {
        try await performDeleteActionsBeforeAuthIsDeleted()
        try await deleteAccount()
    }
}
