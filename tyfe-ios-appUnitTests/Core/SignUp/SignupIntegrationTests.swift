import Foundation
import SwiftfulDataManagers
import Testing
@testable import tyfe_ios_app

@MainActor
struct SignupIntegrationTests {
    @Test func guestUpgradePreservesLocalProgressAndDurablyMergesProfile() async throws {
        let context = try await makeContext()
        let before = context.repository.snapshot
        _ = try await context.interactor.beginEmailRegistration(email: "person@example.com", displayName: "Grace")
        _ = try await context.interactor.verifyEmailRegistrationCode("123456")
        try await context.interactor.finishEmailRegistration(password: "secret123")

        #expect(context.interactor.auth?.uid == context.guest.uid)
        #expect(context.interactor.auth?.isAnonymous == false)
        #expect(context.repository.snapshot == before)
        #expect(context.interactor.pendingEmailRegistration == nil)
        let profile = try #require(context.persistence.document)
        #expect(profile.userId == context.guest.uid)
        #expect(profile.didCompleteOnboarding == true)
        #expect(profile.submittedName == "Grace")
        #expect(profile.creationVersion == "1.0")
        let remoteProfile = try await context.profiles.fetchProfile(userId: context.guest.uid)
        #expect(remoteProfile.displayName == "Grace")
    }

    @Test func diskFailureKeepsProfileStageUntilDurableRetrySucceeds() async throws {
        let context = try await makeContext()
        _ = try await context.interactor.beginEmailRegistration(email: "person@example.com", displayName: "Ada")
        _ = try await context.interactor.verifyEmailRegistrationCode("123456")
        context.persistence.shouldFail = true
        await #expect(throws: SignupPersistenceError.diskFull) {
            try await context.interactor.finishEmailRegistration(password: "secret123")
        }
        #expect(context.interactor.pendingEmailRegistration?.stage == .profile)
        #expect(context.interactor.auth?.uid == context.guest.uid)

        context.persistence.shouldFail = false
        try await context.interactor.finishEmailRegistration(password: "")
        #expect(context.interactor.pendingEmailRegistration == nil)
        #expect(context.persistence.document?.email == "person@example.com")
    }

    @Test func foregroundGuestRefreshCannotUndoThePermanentProfile() async throws {
        let context = try await makeContext()
        let manager = try #require(context.container.resolve(UserManager.self))
        let permanent = UserAuthInfo(uid: context.guest.uid, email: "person@example.com", authProviders: [.email], displayName: "Grace")
        async let refresh: Void = manager.signIn(auth: context.guest, isNewUser: false)
        async let upgrade: Void = manager.reconcileRegistration(auth: permanent)
        _ = try await (refresh, upgrade)
        try await manager.signIn(auth: context.guest, isNewUser: false)
        #expect(manager.currentUser?.isAnonymous == false)
        #expect(manager.currentUser?.submittedName == "Grace")
        #expect(manager.currentUser?.didCompleteOnboarding == true)
        #expect(context.persistence.document?.email == permanent.email)
    }

    private func makeContext() async throws -> SignupIntegrationContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
        let guest = UserAuthInfo(uid: "signup-guest", isAnonymous: true, creationDate: .distantPast)
        let service = MockEmailAuthService(user: guest)
        dependencies.container.register(EmailAuthServicing.self, service: service)
        dependencies.container.register(AuthManager.self, service: AuthManager(service: service))
        let existing = UserModel(userId: guest.uid, creationVersion: "1.0", submittedName: "Ada", didCompleteOnboarding: true)
        let engine = DocumentSyncEngine<UserModel>(
            remote: MockRemoteDocumentService(document: existing),
            managerKey: UserManager.persistenceKey, enableLocalPersistence: false
        )
        let persistence = SignupTestProfilePersistence()
        persistence.document = existing
        persistence.documentId = guest.uid
        let profiles = MockProfileService(profiles: [
            ProfileIdentity(userId: guest.uid, displayName: "Guest")
        ])
        dependencies.container.register(UserManager.self, service: UserManager(
            userSyncEngine: engine,
            profilePersistence: persistence,
            profileService: profiles,
            currentAuthUserId: { service.authenticatedUser?.uid },
            hasPendingRegistration: { service.pendingRegistration != nil }
        ))
        return SignupIntegrationContext(
            guest: guest, interactor: CoreInteractor(container: dependencies.container),
            container: dependencies.container, persistence: persistence,
            repository: try #require(dependencies.container.resolve(LocalAppRepository.self)),
            profiles: profiles
        )
    }
}

@MainActor
private struct SignupIntegrationContext {
    let guest: UserAuthInfo
    let interactor: CoreInteractor
    let container: DependencyContainer
    let persistence: SignupTestProfilePersistence
    let repository: any LocalAppRepository
    let profiles: MockProfileService
}

private enum SignupPersistenceError: Error, Equatable {
    case diskFull
}

@MainActor
private final class SignupTestProfilePersistence: LocalDocumentPersistence {
    var document: UserModel?
    var documentId: String?
    var shouldFail = false

    func saveDocument(managerKey: String, _ document: UserModel?) throws {
        if shouldFail { throw SignupPersistenceError.diskFull }
        self.document = document
    }
    func getDocument(managerKey: String) throws -> UserModel? { document }
    func saveDocumentId(managerKey: String, _ id: String?) throws { documentId = id }
    func getDocumentId(managerKey: String) throws -> String? { documentId }
    func savePendingWrites(managerKey: String, _ writes: [PendingWrite]) throws {}
    func getPendingWrites(managerKey: String) throws -> [PendingWrite] { [] }
    func clearPendingWrites(managerKey: String) throws {}
}
