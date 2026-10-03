import Foundation
import SwiftfulDataManagers
import Testing
@testable import tyfe_ios_app

@MainActor
struct UserProfileTests {
    @Test func nameValidationTrimsAndMatchesDatabaseScalarBoundaries() {
        #expect(ProfileValidation.trimmedName(" \n Ada \t") == "Ada")
        #expect(!ProfileValidation.isValidName(" \n "))
        #expect(ProfileValidation.isValidName(String(repeating: "a", count: 60)))
        #expect(!ProfileValidation.isValidName(String(repeating: "a", count: 61)))
        #expect(ProfileValidation.isValidName(String(repeating: "e\u{301}", count: 30)))
        #expect(!ProfileValidation.isValidName(String(repeating: "e\u{301}", count: 31)))
    }

    @Test func identityFallbackAndAuthoritativeNameSurviveAuthRefresh() {
        #expect(UserModel(userId: "owner", firstName: "First").commonNameCalculated == "First")
        #expect(UserModel(userId: "owner", displayName: "Auth", submittedName: "Chosen").commonNameCalculated == "Chosen")
        var edited = UserModel(userId: "owner", submittedName: "Signup", didCompleteOnboarding: true)
        edited.applyProfile(ProfileIdentity(userId: "owner", displayName: "Edited", avatarPath: "owner/photo.jpg"))
        let refreshed = UserModel(
            auth: UserAuthInfo(uid: "owner", email: "owner@example.com", authProviders: [.email], displayName: "Old auth"),
            creationVersion: nil, existingUser: edited, preferredName: "Old signup"
        )
        #expect(refreshed.commonNameCalculated == "Edited")
        #expect(refreshed.avatarPath == "owner/photo.jpg")
        #expect(refreshed.didCompleteOnboarding == true)
        let other = UserModel(auth: UserAuthInfo(uid: "other"), creationVersion: nil, existingUser: edited)
        #expect(other.submittedName == nil)
        #expect(other.avatarPath == nil)
        let signup = UserModel(
            auth: UserAuthInfo(uid: "owner"), creationVersion: nil,
            existingUser: UserModel(userId: "owner", submittedName: "Guest"), preferredName: "Registration"
        )
        #expect(signup.submittedName == "Registration")
    }

    @Test func refreshPersistsBackendIdentityButNeverSignedPhotoURL() async throws {
        let service = ControlledProfileService()
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        try await manager.refreshProfile()
        #expect(manager.currentUser?.submittedName == "Backend")
        #expect(manager.profilePhotoURL?.host == "profile.invalid")
        #expect(cache.document?.avatarPath == service.profile.avatarPath)
        let encoded = try JSONEncoder().encode(try #require(cache.document))
        let decoded = try JSONDecoder().decode(UserModel.self, from: encoded)
        #expect(decoded.avatarPath == "owner/old.jpg")
        #expect(decoded.photoURL == nil)
        #expect(decoded.submittedProfileImage == nil)
    }

    @Test func offlineFetchRetainsCachedIdentityAndDoesNotBlockLogin() async throws {
        let service = ControlledProfileService()
        service.failFetch = true
        var cached = Self.cachedUser
        cached.applyProfile(ProfileIdentity(userId: "owner", displayName: "Offline edited", avatarPath: "owner/old.jpg"))
        let cache = ProfileCache(document: cached)
        let manager = Self.manager(service: service, cache: cache)
        await #expect(throws: ProfileTestError.self) { try await manager.refreshProfile() }
        try await manager.signIn(auth: Self.auth, isNewUser: false, preferredName: "Old signup")
        #expect(manager.currentUser?.submittedName == "Offline edited")
        #expect(cache.document?.avatarPath == "owner/old.jpg")
    }

    @Test func uploadFailureDoesNotChangeProfileOrCache() async {
        let service = ControlledProfileService()
        service.failUpload = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        await #expect(throws: ProfileTestError.self) { try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg)) }
        #expect(service.profile.displayName == "Backend")
        #expect(cache.document?.submittedName == "Cached")
        #expect(service.photos == ["owner/old.jpg"])
    }

    @Test func failedCommitRollsBackOnlyNewUploadAndKeepsDraftIdentityCached() async {
        let service = ControlledProfileService()
        service.failSave = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        await #expect(throws: ProfileTestError.self) { try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg)) }
        #expect(service.photos == ["owner/old.jpg"])
        #expect(service.profile.avatarPath == "owner/old.jpg")
        #expect(cache.document?.submittedName == "Cached")
    }

    @Test func lostSaveResponseReconcilesCommittedProfileWithoutDuplicateUpload() async throws {
        let service = ControlledProfileService()
        service.commitThenFail = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg))
        #expect(manager.currentUser?.submittedName == "Changed")
        #expect(service.photos == ["owner/new-1.jpg"])
        #expect(service.profile.avatarPath == "owner/new-1.jpg")
    }

    @Test func removalClearsReferenceBeforeStorageDelete() async throws {
        let service = ControlledProfileService()
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        try await manager.saveProfile(name: "Changed", photo: .remove)
        #expect(service.profile.avatarPath == nil)
        #expect(service.photos.isEmpty)
        #expect(cache.document?.avatarPath == nil)
        #expect(manager.profilePhotoURL == nil)
    }

    @Test func committedSaveRemainsSuccessfulWhenDiskURLAndCleanupFail() async throws {
        let service = ControlledProfileService()
        service.failRemove = true
        service.failResolve = true
        let cache = ProfileCache(document: Self.cachedUser)
        cache.failWrites = true
        let manager = Self.manager(service: service, cache: cache)
        try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg))
        #expect(manager.currentUser?.submittedName == "Changed")
        #expect(manager.currentUser?.avatarPath == "owner/new-1.jpg")
        #expect(manager.profilePhotoURL == nil)
        #expect(service.photos == ["owner/old.jpg", "owner/new-1.jpg"])
        cache.failWrites = false
        service.failRemove = false
        try await manager.refreshProfile()
        #expect(service.photos == ["owner/new-1.jpg"])
        #expect(cache.document?.submittedName == "Changed")
    }

    @Test func uncertainCommitDoesNotDeletePotentiallyReferencedUpload() async throws {
        let service = ControlledProfileService()
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        service.commitThenFail = true
        service.failFetch = true
        await #expect(throws: ProfileTestError.self) { try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg)) }
        #expect(service.profile.avatarPath == "owner/new-1.jpg")
        #expect(service.photos.contains("owner/new-1.jpg"))
        service.failFetch = false
        try await manager.refreshProfile()
        #expect(manager.currentUser?.submittedName == "Changed")
        #expect(service.photos.contains("owner/new-1.jpg"))
    }

    @Test func liveAuthSwitchBeforeSignInRejectsLateRefreshCacheWrite() async throws {
        let service = ControlledProfileService()
        service.suspendFetch = true
        let cache = ProfileCache(document: Self.cachedUser)
        var activeUID: String? = "owner"
        let manager = Self.manager(service: service, cache: cache, currentAuthUserId: { activeUID })
        let refresh = Task { try await manager.refreshProfile() }
        await service.waitForFetch()
        activeUID = "other"
        service.finishFetch()
        await #expect(throws: UserManager.UserManagerError.self) { try await refresh.value }
        #expect(cache.document?.submittedName == "Cached")
        #expect(manager.currentUser == nil)
        #expect(manager.profilePhotoURL == nil)
    }

    @Test func logoutGenerationRejectsLateRefreshCompletion() async throws {
        let service = ControlledProfileService()
        service.suspendFetch = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        let refresh = Task { try await manager.refreshProfile() }
        await service.waitForFetch()
        manager.signOut()
        service.finishFetch()
        await #expect(throws: UserManager.UserManagerError.self) { try await refresh.value }
        #expect(manager.currentUser == nil)
        #expect(cache.document == nil)
        #expect(manager.profilePhotoURL == nil)
    }

    @Test func sameUIDReloginStillRejectsPreviousSessionCompletion() async throws {
        let service = ControlledProfileService()
        service.suspendFetch = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache, hasPendingRegistration: { true })
        let oldGeneration = manager.profileSessionGeneration
        let refresh = Task { try await manager.refreshProfile() }
        await service.waitForFetch()
        manager.signOut()
        try await manager.signIn(auth: Self.auth, isNewUser: false)
        service.finishFetch()
        await #expect(throws: UserManager.UserManagerError.self) { try await refresh.value }
        #expect(manager.currentUser?.userId == "owner")
        #expect(manager.currentUser?.submittedName != "Backend")
        #expect(manager.profilePhotoURL == nil)
        #expect(manager.profileSessionGeneration != oldGeneration)
    }

    @Test func committedSaveFromPreviousAccountNeverWritesCurrentCache() async throws {
        let service = ControlledProfileService()
        service.suspendSave = true
        let cache = ProfileCache(document: Self.cachedUser)
        var activeUID: String? = "owner"
        let manager = Self.manager(service: service, cache: cache, currentAuthUserId: { activeUID })
        let save = Task { try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg)) }
        await service.waitForSave()
        activeUID = "other"
        service.finishSave()
        await #expect(throws: UserManager.UserManagerError.self) { try await save.value }
        #expect(cache.document?.submittedName == "Cached")
        #expect(manager.currentUser == nil)
        #expect(manager.profilePhotoURL == nil)
        #expect(service.photos.contains("owner/new-1.jpg"))
    }

    @Test func pendingSignupCannotFetchPlaceholderBeforeRegistrationNameIsSaved() async throws {
        let service = ControlledProfileService()
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache, hasPendingRegistration: { true })
        try await manager.signIn(auth: Self.auth, isNewUser: false)
        #expect(manager.currentUser?.submittedName == "Cached")
        #expect(manager.currentUser?.hasAuthoritativeProfileName != true)
        try await manager.reconcileRegistration(auth: Self.auth)
        #expect(service.profile.displayName == "Old auth")
        #expect(service.profile.avatarPath == "owner/old.jpg")
        #expect(cache.document?.submittedName == "Old auth")
        #expect(cache.document?.hasAuthoritativeProfileName == true)
        let outdated = UserAuthInfo(uid: "owner", authProviders: [.email], displayName: "Stale registration")
        try await manager.reconcileRegistration(auth: outdated)
        #expect(service.profile.displayName == "Old auth")
        #expect(cache.document?.submittedName == "Old auth")
    }

    @Test func registrationPreservesRemotePhotoMissingFromLocalCache() async throws {
        let service = ControlledProfileService()
        let cache = ProfileCache(document: UserModel(userId: "owner", submittedName: "Guest"))
        let manager = Self.manager(service: service, cache: cache, hasPendingRegistration: { true })
        try await manager.reconcileRegistration(auth: Self.auth)
        #expect(service.profile.displayName == "Old auth")
        #expect(service.profile.avatarPath == "owner/old.jpg")
        #expect(service.photos == ["owner/old.jpg"])
        #expect(cache.document?.avatarPath == "owner/old.jpg")
    }

    @Test func failedRollbackRemainsRetryableAfterManagerRecreation() async throws {
        let suite = "UserProfileTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let service = ControlledProfileService()
        service.failSave = true
        service.failRemove = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache, cleanupDefaults: defaults)
        await #expect(throws: ProfileTestError.self) { try await manager.saveProfile(name: "Changed", photo: .replace(Self.jpeg)) }
        #expect(service.photos.contains("owner/new-1.jpg"))
        service.failRemove = false
        let restored = Self.manager(service: service, cache: cache, cleanupDefaults: defaults)
        try await restored.refreshProfile()
        #expect(service.photos == ["owner/old.jpg"])
        #expect(restored.currentUser?.submittedName == "Backend")
    }

    @Test func storageDeletionFailureRetainsLocalUserForRetry() async throws {
        let service = ControlledProfileService()
        service.failRemove = true
        let cache = ProfileCache(document: Self.cachedUser)
        let manager = Self.manager(service: service, cache: cache)
        await #expect(throws: ProfileTestError.self) { try await manager.removeAllProfilePhotos() }
        #expect(manager.currentUser?.userId == "owner")
        #expect(cache.document?.userId == "owner")
        service.failRemove = false
        try await manager.removeAllProfilePhotos()
        #expect(service.photos.isEmpty)
        try await manager.deleteCurrentUser()
        #expect(manager.currentUser == nil)
        #expect(cache.document == nil)
    }

    @Test func unavailableServiceNeverClaimsRemoteSaveOrDeletion() async {
        let manager = Self.manager(service: UnavailableProfileService(), cache: ProfileCache(document: Self.cachedUser))
        await #expect(throws: ProfileServiceError.unavailable) { try await manager.saveProfile(name: "Changed", photo: .unchanged) }
        await #expect(throws: ProfileServiceError.unavailable) { try await manager.removeAllProfilePhotos() }
        #expect(manager.currentUser?.submittedName == "Cached")
    }

    @Test func mockPreservesAvatarTokenAndNamesAcrossRepeatedFetches() async throws {
        let service = MockProfileService(profiles: [ProfileIdentity(userId: "owner", displayName: "Before", avatarToken: "leaf")])
        let photo = try await service.uploadPhoto(userId: "owner", jpeg: Self.jpeg)
        let localURL = try await service.resolvePhotoURL(path: photo)
        #expect(localURL.isFileURL)
        #expect(try Data(contentsOf: localURL) == Self.jpeg)
        _ = try await service.saveProfile(userId: "owner", name: "  After  ", avatarPath: photo)
        let refreshed = try await service.fetchProfile(userId: "owner")
        #expect(refreshed.displayName == "After")
        #expect(refreshed.avatarToken == "leaf")
        #expect(refreshed.avatarPath == "owner/00000000-0000-0000-0000-000000000001.jpg")
        let removed = try await service.saveProfile(userId: "owner", name: "After", avatarPath: nil)
        #expect(removed.avatarPath == nil)
        #expect(removed.avatarToken == "leaf")
        try await service.removePhoto(path: photo)
        #expect(!FileManager.default.fileExists(atPath: localURL.path))
        await #expect(throws: ProfileServiceError.invalidPath) { try await service.resolvePhotoURL(path: photo) }
    }

    private static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xD9])
    private static var cachedUser: UserModel {
        UserModel(userId: "owner", creationVersion: "1", submittedName: "Cached", avatarPath: "owner/old.jpg", didCompleteOnboarding: true)
    }
    private static var auth: UserAuthInfo {
        UserAuthInfo(uid: "owner", email: "owner@example.com", authProviders: [.email], displayName: "Old auth")
    }
    private static func manager(
        service: any ProfileServicing, cache: ProfileCache,
        currentAuthUserId: (@MainActor () -> String?)? = nil,
        hasPendingRegistration: (@MainActor () -> Bool)? = nil,
        cleanupDefaults: UserDefaults? = nil
    ) -> UserManager {
        UserManager(
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: nil), managerKey: "ProfileTests", enableLocalPersistence: false
            ),
            profilePersistence: cache, profileService: service, currentAuthUserId: currentAuthUserId,
            hasPendingRegistration: hasPendingRegistration, cleanupDefaults: cleanupDefaults
        )
    }
}

private enum ProfileTestError: Error { case unavailable }

@MainActor
private final class ControlledProfileService: ProfileServicing {
    var profile = ProfileIdentity(userId: "owner", displayName: "Backend", avatarToken: "leaf", avatarPath: "owner/old.jpg")
    var photos: Set<String> = ["owner/old.jpg"]
    var failFetch = false
    var failUpload = false
    var failSave = false
    var commitThenFail = false
    var failRemove = false
    var failResolve = false
    var suspendFetch = false
    var suspendSave = false
    private var uploadCount = 0
    private var fetchContinuation: CheckedContinuation<ProfileIdentity, any Error>?
    private var fetchStarted: CheckedContinuation<Void, Never>?
    private var saveContinuation: CheckedContinuation<ProfileIdentity, any Error>?
    private var saveStarted: CheckedContinuation<Void, Never>?

    func waitForSave() async {
        if saveContinuation != nil { return }
        await withCheckedContinuation { saveStarted = $0 }
    }
    func finishSave() {
        saveContinuation?.resume(returning: profile)
        saveContinuation = nil
        suspendSave = false
    }

    func waitForFetch() async {
        if fetchContinuation != nil { return }
        await withCheckedContinuation { fetchStarted = $0 }
    }
    func finishFetch() {
        fetchContinuation?.resume(returning: profile)
        fetchContinuation = nil
        suspendFetch = false
    }
    func fetchProfile(userId: String) async throws -> ProfileIdentity {
        if failFetch { throw ProfileTestError.unavailable }
        if suspendFetch {
            return try await withCheckedThrowingContinuation {
                fetchContinuation = $0
                fetchStarted?.resume()
                fetchStarted = nil
            }
        }
        return profile
    }
    func saveProfile(userId: String, name: String, avatarPath: String?) async throws -> ProfileIdentity {
        if failSave { throw ProfileTestError.unavailable }
        if let avatarPath, !photos.contains(avatarPath) { throw ProfileTestError.unavailable }
        profile = ProfileIdentity(userId: userId, displayName: name, avatarToken: profile.avatarToken, avatarPath: avatarPath)
        if commitThenFail { throw ProfileTestError.unavailable }
        if suspendSave {
            return try await withCheckedThrowingContinuation {
                saveContinuation = $0
                saveStarted?.resume()
                saveStarted = nil
            }
        }
        return profile
    }
    func uploadPhoto(userId: String, jpeg: Data) async throws -> String {
        if failUpload { throw ProfileTestError.unavailable }
        uploadCount += 1
        let path = "\(userId)/new-\(uploadCount).jpg"
        photos.insert(path)
        return path
    }
    func removePhoto(path: String) async throws {
        // Enforce the consumer-visible invariant: referenced photos are never removed.
        if failRemove || profile.avatarPath == path { throw ProfileTestError.unavailable }
        photos.remove(path)
    }
    func resolvePhotoURL(path: String) async throws -> URL {
        if failResolve { throw ProfileTestError.unavailable }
        return URL(string: "https://profile.invalid/\(path)?token=transient")!
    }
    func removeAllPhotos(userId: String) async throws {
        if failRemove { throw ProfileTestError.unavailable }
        photos = photos.filter { !$0.hasPrefix("\(userId)/") }
    }
}

@MainActor
private final class ProfileCache: LocalDocumentPersistence {
    var document: UserModel?
    var failWrites = false
    private var documentId: String?
    init(document: UserModel?) { self.document = document }
    func saveDocument(managerKey: String, _ document: UserModel?) throws {
        if failWrites { throw ProfileTestError.unavailable }
        self.document = document
    }
    func getDocument(managerKey: String) throws -> UserModel? { document }
    func saveDocumentId(managerKey: String, _ id: String?) throws { documentId = id }
    func getDocumentId(managerKey: String) throws -> String? { documentId }
    func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws {}
    func getPendingWrites(managerKey: String) throws -> [PendingWrite] { [] }
    func clearPendingWrites(managerKey: String) throws {}
}
