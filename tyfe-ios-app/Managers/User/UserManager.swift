//
//  UserManager2.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 1/17/25.
//

import SwiftUI
import SwiftfulDataManagers

@MainActor
@Observable
class UserManager {

    private let userSyncEngine: DocumentSyncEngine<UserModel>
    private let profilePersistence: (any LocalDocumentPersistence<UserModel>)?
    private let profileService: any ProfileServicing
    private let currentAuthUserId: (@MainActor () -> String?)?
    private let hasPendingRegistration: (@MainActor () -> Bool)?
    private let cleanupDefaults: UserDefaults?
    @ObservationIgnored private var profileTask: Task<Void, Error>?
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var lastSignedInAuth: UserAuthInfo?
    @ObservationIgnored private var cleanupPathsByUser: [String: [String]]
    private var storedUser: UserModel?
    private var resolvedPhotoURL: URL?

    var profilePhotoURL: URL? {
        currentUser == nil ? nil : resolvedPhotoURL
    }

    var profileSessionGeneration: Int { sessionGeneration }
    static let persistenceKey = "UserMan"
    private static let cleanupKey = "tyfe.profile-photo-cleanup"
    private var logger: (any DataSyncLogger)? { userSyncEngine.logger }

    var currentUser: UserModel? {
        guard let storedUser else { return nil }
        if let currentAuthUserId, currentAuthUserId() != storedUser.userId { return nil }
        return storedUser
    }

    init(
        userSyncEngine: DocumentSyncEngine<UserModel>,
        profilePersistence: (any LocalDocumentPersistence<UserModel>)? = nil,
        profileService: any ProfileServicing = UnavailableProfileService(),
        currentAuthUserId: (@MainActor () -> String?)? = nil,
        hasPendingRegistration: (@MainActor () -> Bool)? = nil,
        cleanupDefaults: UserDefaults? = nil
    ) {
        self.userSyncEngine = userSyncEngine
        self.profilePersistence = profilePersistence
        self.profileService = profileService
        self.currentAuthUserId = currentAuthUserId
        self.hasPendingRegistration = hasPendingRegistration
        self.cleanupDefaults = cleanupDefaults
        self.cleanupPathsByUser = cleanupDefaults?.dictionary(forKey: Self.cleanupKey) as? [String: [String]] ?? [:]
        self.storedUser = (try? profilePersistence?.getDocument(managerKey: Self.persistenceKey))
            ?? userSyncEngine.currentDocument
        // Engine listeners commit cache writes internally, without our session guards.
        userSyncEngine.stopListening(clearCaches: false)
    }

    private func restoreAuth(auth: UserAuthInfo, isNewUser: Bool, preferredName: String?) throws -> Bool {
        if let currentAuthUserId, currentAuthUserId() != auth.uid { throw UserManagerError.userIdChanged }
        if auth.isAnonymous, lastSignedInAuth?.uid == auth.uid, lastSignedInAuth?.isAnonymous == false { return false }
        if storedUser?.userId != auth.uid {
            sessionGeneration += 1
            profileTask?.cancel()
            profileTask = nil
            resolvedPhotoURL = nil
        }
        lastSignedInAuth = auth
        let user = UserModel(
            auth: auth, creationVersion: isNewUser ? Utilities.appVersion : nil,
            existingUser: storedUser, preferredName: preferredName
        )
        logger?.trackEvent(event: Event.logInStart)
        try persist(user)
        storedUser = user
        logger?.trackEvent(event: Event.logInSuccess)
        return !auth.isAnonymous
    }

    func signIn(auth: UserAuthInfo, isNewUser: Bool, preferredName: String? = nil) async throws {
        guard try restoreAuth(auth: auth, isNewUser: isNewUser, preferredName: preferredName),
              hasPendingRegistration?() != true else { return }
        // A placeholder profile must not overwrite the name while signup is still pending.
        let generation = sessionGeneration
        try await enqueue(userId: auth.uid, generation: generation) {
            do {
                try await self.fetchAndApplyProfile(userId: auth.uid, generation: generation)
            } catch {
                try self.requireSession(userId: auth.uid, generation: generation)
            }
        }
    }

    func getUser() async throws -> UserModel {
        guard let currentUser else { throw UserManagerError.noUserId }
        return currentUser
    }

    func reconcileRegistration(auth: UserAuthInfo) async throws {
        let alreadyAuthoritative = storedUser?.userId == auth.uid && storedUser?.hasAuthoritativeProfileName == true
        _ = try restoreAuth(auth: auth, isNewUser: false, preferredName: auth.displayName)
        let generation = sessionGeneration
        if !alreadyAuthoritative, let name = auth.displayName, ProfileValidation.isValidName(name) {
            try await enqueue(userId: auth.uid, generation: generation) {
                let existing = try await self.profileService.fetchProfile(userId: auth.uid)
                try self.requireSession(userId: auth.uid, generation: generation)
                try await self.commitProfile(
                    userId: auth.uid, generation: generation, name: ProfileValidation.trimmedName(name),
                    photo: .unchanged, existingProfile: existing
                )
            }
        }
        guard let user = currentUser, user.userId == auth.uid else { throw UserManagerError.userIdChanged }
        // Signup explicitly acknowledges a durable cache write, unlike remote profile success.
        try persist(user)
    }

    func saveOnboardingCompleteForCurrentUser() async throws {
        guard var user = currentUser else { throw UserManagerError.noUserId }
        user.markDidCompleteOnboarding()
        try persist(user)
        storedUser = user
    }

    func refreshProfile() async throws {
        let uid = try currentUserId()
        let generation = sessionGeneration
        try await enqueue(userId: uid, generation: generation) {
            try await self.fetchAndApplyProfile(userId: uid, generation: generation)
        }
    }

    func saveProfile(name: String, photo: ProfilePhotoChange) async throws {
        guard ProfileValidation.isValidName(name) else { throw ProfileServiceError.invalidName }
        let uid = try currentUserId()
        let generation = sessionGeneration
        try await enqueue(userId: uid, generation: generation) {
            try await self.commitProfile(
                userId: uid, generation: generation, name: ProfileValidation.trimmedName(name), photo: photo
            )
        }
    }

    func removeAllProfilePhotos() async throws {
        let uid = try currentUserId()
        let generation = sessionGeneration
        try await enqueue(userId: uid, generation: generation) {
            try await self.profileService.removeAllPhotos(userId: uid)
            try self.requireSession(userId: uid, generation: generation)
            self.cleanupPathsByUser[uid] = nil
            self.persistCleanupQueue()
            self.resolvedPhotoURL = nil
        }
    }

    private func enqueue(
        userId: String, generation: Int, operation: @escaping @MainActor () async throws -> Void
    ) async throws {
        let previous = profileTask
        let task = Task { @MainActor in
            _ = try? await previous?.value
            try Task.checkCancellation()
            try self.requireSession(userId: userId, generation: generation)
            try await operation()
        }
        profileTask = task
        try await task.value
    }

    private func fetchAndApplyProfile(userId: String, generation: Int) async throws {
        let profile = try await profileService.fetchProfile(userId: userId)
        try requireSession(userId: userId, generation: generation)
        if let path = profile.avatarPath { forgetPhotoCleanup(path, userId: userId) }
        try applyProfile(profile, userId: userId)
        await resolvePhoto(profile.avatarPath, userId: userId, generation: generation)
        try requireSession(userId: userId, generation: generation)
        await retryPhotoCleanup(userId: userId, generation: generation)
    }

    private func commitProfile(
        userId: String, generation: Int, name: String, photo: ProfilePhotoChange,
        existingProfile: ProfileIdentity? = nil
    ) async throws {
        if let existingProfile, existingProfile.userId != userId { throw UserManagerError.userIdChanged }
        let oldPath = existingProfile == nil ? currentUser?.avatarPath : existingProfile?.avatarPath
        var path = oldPath
        var uploadedPath: String?
        var canRollback = true
        do {
            switch photo {
            case .unchanged: break
            case .remove: path = nil
            case .replace(let jpeg):
                let uploaded = try await profileService.uploadPhoto(userId: userId, jpeg: jpeg)
                uploadedPath = uploaded
                path = uploaded
                // Retain rollback work across failures, logout, and app restarts.
                queuePhotoCleanup(uploaded, userId: userId)
                try requireSession(userId: userId, generation: generation)
            }
            if let oldPath, oldPath != path { queuePhotoCleanup(oldPath, userId: userId) }
            canRollback = false
            let profile = try await saveRemoteProfile(
                userId: userId, generation: generation, name: name, path: path, canRollback: &canRollback
            )
            // A committed reference must never be deleted as a rollback.
            if let referenced = profile.avatarPath { forgetPhotoCleanup(referenced, userId: userId) }
            if let oldPath, oldPath != profile.avatarPath { queuePhotoCleanup(oldPath, userId: userId) }
            try requireSession(userId: userId, generation: generation)
            try applyProfile(profile, userId: userId)
            // URL, disk, and obsolete-object cleanup failures must not report a failed remote save.
            await resolvePhoto(profile.avatarPath, userId: userId, generation: generation)
            await retryPhotoCleanup(userId: userId, generation: generation)
        } catch {
            if canRollback, let uploadedPath, cleanupPathsByUser[userId]?.contains(uploadedPath) == true {
                await retryPhotoCleanup(userId: userId, generation: generation)
            }
            throw error
        }
    }

    private func saveRemoteProfile(
        userId: String, generation: Int, name: String, path: String?, canRollback: inout Bool
    ) async throws -> ProfileIdentity {
        do {
            return try await profileService.saveProfile(userId: userId, name: name, avatarPath: path)
        } catch {
            let saveError = error
            try requireSession(userId: userId, generation: generation)
            // A lost response can hide a committed update. Reconcile before deleting an upload.
            guard let latest = try? await profileService.fetchProfile(userId: userId) else { throw saveError }
            try requireSession(userId: userId, generation: generation)
            if let referenced = latest.avatarPath { forgetPhotoCleanup(referenced, userId: userId) }
            guard latest.displayName == name, latest.avatarPath == path else {
                canRollback = true
                throw saveError
            }
            return latest
        }
    }

    private func applyProfile(_ profile: ProfileIdentity, userId: String) throws {
        guard profile.userId == userId, var user = currentUser, user.userId == userId else {
            throw UserManagerError.userIdChanged
        }
        user.applyProfile(profile)
        storedUser = user
        try? persist(user)
    }

    private func resolvePhoto(_ path: String?, userId: String, generation: Int) async {
        let url: URL?
        if let path {
            url = try? await profileService.resolvePhotoURL(path: path)
        } else {
            url = nil
        }
        guard (try? requireSession(userId: userId, generation: generation)) != nil else { return }
        resolvedPhotoURL = url
    }

    private func retryPhotoCleanup(userId: String, generation: Int) async {
        for path in cleanupPathsByUser[userId] ?? [] {
            guard (try? requireSession(userId: userId, generation: generation)) != nil else { return }
            do {
                try await profileService.removePhoto(path: path)
                try requireSession(userId: userId, generation: generation)
                forgetPhotoCleanup(path, userId: userId)
            } catch {
                // Keep failed cleanup retryable; an already committed profile remains successful.
            }
        }
    }

    private func queuePhotoCleanup(_ path: String, userId: String) {
        if cleanupPathsByUser[userId]?.contains(path) != true {
            cleanupPathsByUser[userId, default: []].append(path)
            persistCleanupQueue()
        }
    }

    private func forgetPhotoCleanup(_ path: String, userId: String) {
        cleanupPathsByUser[userId]?.removeAll { $0 == path }
        if cleanupPathsByUser[userId]?.isEmpty == true { cleanupPathsByUser[userId] = nil }
        persistCleanupQueue()
    }

    private func persistCleanupQueue() {
        cleanupDefaults?.set(cleanupPathsByUser, forKey: Self.cleanupKey)
    }

    private func persist(_ user: UserModel) throws {
        try profilePersistence?.saveDocument(managerKey: Self.persistenceKey, user)
        try profilePersistence?.saveDocumentId(managerKey: Self.persistenceKey, user.userId)
    }

    private func requireSession(userId: String, generation: Int) throws {
        guard generation == sessionGeneration, currentUser?.userId == userId,
              currentAuthUserId == nil || currentAuthUserId?() == userId else {
            throw UserManagerError.userIdChanged
        }
    }

    func signOut() {
        sessionGeneration += 1
        profileTask?.cancel()
        profileTask = nil
        lastSignedInAuth = nil
        storedUser = nil
        resolvedPhotoURL = nil
        userSyncEngine.stopListening()
        try? profilePersistence?.saveDocument(managerKey: Self.persistenceKey, nil)
        try? profilePersistence?.saveDocumentId(managerKey: Self.persistenceKey, nil)
        logger?.trackEvent(event: Event.signOut)
    }

    // Auth's deletion RPC has already succeeded. Local cleanup cannot undo that remote success.
    func deleteCurrentUser() async throws {
        signOut()
        logger?.trackEvent(event: Event.deleteAccountSuccess)
    }

    private func currentUserId() throws -> String {
        guard let uid = currentUser?.userId else { throw UserManagerError.noUserId }
        return uid
    }

    enum UserManagerError: LocalizedError {
        case noUserId
        case userIdChanged

        var errorDescription: String? {
            switch self {
            case .noUserId: return "Sign in to edit your profile."
            case .userIdChanged: return "Your account changed. Reopen your profile to continue."
            }
        }
    }

    static func mock(user: UserModel? = nil) -> UserManager {
        let manager = UserManager(
            userSyncEngine: DocumentSyncEngine<UserModel>(
                remote: MockRemoteDocumentService(document: user),
                managerKey: persistenceKey, enableLocalPersistence: false
            ),
            profileService: MockProfileService(profiles: user.map {
                [ProfileIdentity(userId: $0.userId, displayName: $0.commonNameCalculated ?? "Friend", avatarPath: $0.avatarPath)]
            } ?? [])
        )
        manager.storedUser = user
        return manager
    }

    enum Event: DataSyncLogEvent {
        case logInStart
        case logInSuccess
        case signOut
        case deleteAccountSuccess

        var eventName: String {
            switch self {
            case .logInStart: return "UserMan2_LogIn_Start"
            case .logInSuccess: return "UserMan2_LogIn_Success"
            case .signOut: return "UserMan2_SignOut"
            case .deleteAccountSuccess: return "UserMan2_DeleteAccount_Success"
            }
        }

        var parameters: [String: Any]? { nil }
        var type: DataLogType { .analytic }
    }
}
