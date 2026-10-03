import Foundation
import SwiftfulRouting
import Testing
import UIKit
@testable import tyfe_ios_app

@MainActor
struct CirclesAccessTests {
    @Test(arguments: [false, true])
    func missingOrGuestSessionCannotReadOrMutateCircles(isGuest: Bool) async throws {
        let context = try makeContext(user: isGuest ? .mock(isAnonymous: true) : nil)
        let interactor = context.interactor
        let userId = UserAuthInfo.mock().uid
        let operations: [@MainActor () async throws -> Void] = [
            { try await interactor.refreshSocialCircles(userId: userId) },
            { _ = try await interactor.createCircle(name: "Circle", ownerId: userId) },
            { _ = try await interactor.updateCircle(circleId: "c1", name: "Renamed") },
            { try await interactor.deleteCircle(circleId: "c1") },
            { _ = try await interactor.createCircleInvite(circleId: "c1", createdBy: userId, expiresAt: .distantFuture) },
            { try await interactor.revokeCircleInvite(inviteId: "invite") },
            { _ = try await interactor.acceptCircleInvite(code: "ABCD2345") },
            { _ = try await interactor.circleMembers(circleId: "c1") },
            { _ = try await interactor.circleMemberProgress(circleId: "c1") },
            { try await interactor.leaveCircle(circleId: "c1", userId: userId) },
            { try await interactor.removeCircleMember(circleId: "c1", userId: "other") },
            { try await interactor.sendCheer(.clap, recipientId: "other") },
            { try await interactor.refreshSocialCheers() },
            { try await interactor.updateSocialDisplayName("Name", userId: userId) },
            { try await interactor.migrateLocalToSocial() }
        ]

        for operation in operations {
            await #expect(throws: SocialServiceError.notAuthenticated) { try await operation() }
        }
        #expect(!interactor.canAccessCircles)
        #expect(!interactor.isSocialMigrationComplete)
        let circles = try await context.service.fetchCircles(userId: userId)
        #expect(circles.map(\.name) == ["Circle"])
    }

    @Test func guestHidesCachedDataAndStopsRealtimeWithoutPublishingProgress() async throws {
        let context = try makeContext(user: .mock(isAnonymous: true))
        let userId = UserAuthInfo.mock().uid
        try await context.interactor.socialManager.refreshCircles(for: userId)
        context.interactor.socialManager.startRealtime(circleIds: ["c1"], recipientId: userId)
        let before = try await context.service.fetchCircleProgress(circleId: "c1")

        await context.interactor.syncSocialRealtime()
        context.interactor.startSocialRealtime(circleIds: ["c1"])
        await context.interactor.syncSharedProgress()
        await context.interactor.updateSocialFocusStatus(.focusing)

        #expect(context.interactor.socialCircles.isEmpty)
        #expect(context.interactor.socialFocusStatuses.isEmpty)
        #expect(context.interactor.socialCheers.isEmpty)
        #expect(context.interactor.pendingReceivedCheerCount == 0)
        #expect(context.interactor.socialManager.activeFocusCircleIds.isEmpty)
        #expect(!context.interactor.isSocialMigrationComplete)
        let after = try await context.service.fetchCircleProgress(circleId: "c1")
        #expect(after == before)
    }

    @Test(arguments: [PendingEmailRegistration.Stage.verification, .password, .profile])
    func unfinishedSignupRemainsLocked(stage: PendingEmailRegistration.Stage) async throws {
        let context = try makeContext(user: .mock(), pendingStage: stage)
        #expect(!context.interactor.canAccessCircles)
        #expect(!context.presenter.canAccessCircles)
        #expect(context.presenter.accountActionTitle == "Finish creating account")
        await #expect(throws: SocialServiceError.notAuthenticated) {
            _ = try await context.interactor.createCircle(name: "Circle", ownerId: UserAuthInfo.mock().uid)
        }
        context.presenter.onViewAppear(delegate: CirclesDelegate())
        await context.presenter.refreshTask?.value
        #expect(context.presenter.circles.isEmpty)
        #expect(!context.presenter.isOffline)
    }

    @Test func lockedActionsPresentAuthenticationWithoutEnablingGuestAccess() throws {
        let context = try makeContext(user: .mock(isAnonymous: true))
        context.presenter.onCreateAccountTapped()
        context.presenter.onSignInTapped()
        #expect(context.router.signupDelegate != nil)
        #expect(context.router.signInCount == 1)
        #expect(context.interactor.auth?.isAnonymous == true)
        #expect(context.interactor.pendingEmailRegistration == nil)

        context.presenter.onCreateCircleTapped()
        context.presenter.onJoinCircleTapped()
        context.presenter.onSelectCircle("c1")
        #expect(!context.presenter.isCreateCirclePresented)
        #expect(!context.presenter.isJoinCirclePresented)
        #expect(context.presenter.selectedCircleId == nil)
    }

    @Test func signupCompletionUnlocksAndRefreshesThenSignOutClearsScreen() async throws {
        let context = try makeContext(user: .mock(), pendingStage: .profile)
        context.presenter.onCreateAccountTapped()
        #expect(!context.presenter.canAccessCircles)

        try context.emailService.acknowledgeRegistrationComplete()
        context.router.signupDelegate?.onDidSignIn?()
        await context.presenter.refreshTask?.value
        #expect(context.presenter.canAccessCircles)
        #expect(context.presenter.circles.map(\.circleId) == ["c1"])
        #expect(context.interactor.socialManager.activeFocusCircleIds == ["c1"])
        context.presenter.onCreateCircleTapped()

        try context.authManager.signOut()
        #expect(!context.presenter.canAccessCircles)
        context.presenter.onAccountStatusChanged()
        await context.presenter.refreshTask?.value
        #expect(context.presenter.circles.isEmpty)
        #expect(context.presenter.members.isEmpty)
        #expect(context.presenter.selectedCircleId == nil)
        #expect(!context.presenter.isCreateCirclePresented)
        #expect(context.interactor.socialManager.activeFocusCircleIds.isEmpty)
    }

    @Test func signInCompletionRefreshesCirclesForAnExistingAccount() async throws {
        let context = try makeContext(user: .mock())
        context.presenter.onSignInTapped()
        context.router.signInCompletion?()
        await context.presenter.refreshTask?.value
        #expect(context.presenter.canAccessCircles)
        #expect(context.presenter.circles.map(\.circleId) == ["c1"])
    }

    @Test func entryAndForegroundRefreshAuthoritativeCircleIdentity() async throws {
        let userId = UserAuthInfo.mock().uid
        let profile = MockProfileService(profiles: [
            ProfileIdentity(userId: userId, displayName: "First Name", avatarToken: "🌻", avatarPath: nil)
        ])
        let context = try makeContext(user: .mock(), profileService: profile)
        context.presenter.onViewAppear(delegate: CirclesDelegate())
        await context.presenter.refreshTask?.value
        let initial = try #require(context.presenter.members.first)
        #expect(initial.displayName == "First Name")
        #expect(initial.avatarFallbackText == "🌻")
        #expect(context.presenter.photoURL(for: initial) == nil)

        _ = try await profile.saveProfile(userId: userId, name: "Latest Name", avatarPath: "\(userId)/photo.jpg")
        context.presenter.onSceneBecameActive()
        await context.presenter.refreshTask?.value
        let updated = try #require(context.presenter.members.first)
        #expect(updated.displayName == "Latest Name")
        #expect(updated.avatarToken == "🌻")
        #expect(updated.avatarPath == "\(userId)/photo.jpg")
        #expect(updated.avatarFallbackText == "🌻")
        #expect(context.presenter.photoURL(for: updated) == nil)
        context.presenter.onViewDisappear(delegate: CirclesDelegate())
    }

    @Test(arguments: [(true, false), (false, true), (true, true)])
    func optionalSocialFailuresDoNotSuppressFreshIdentities(failCheers: Bool, failProgress: Bool) async throws {
        let userId = UserAuthInfo.mock().uid
        let profile = MockProfileService(profiles: [
            ProfileIdentity(userId: userId, displayName: "Original Name", avatarToken: "🌻", avatarPath: nil)
        ])
        let context = try makeContext(
            user: .mock(), profileService: profile, failCheers: failCheers, failProgress: failProgress
        )
        context.presenter.onViewAppear(delegate: CirclesDelegate())
        await context.presenter.refreshTask?.value
        #expect(context.presenter.circles.map(\.circleId) == ["c1"])
        #expect(context.presenter.members.first?.displayName == "Original Name")
        #expect(!context.presenter.isOffline)

        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).jpegData(withCompressionQuality: 0.8) { context in
            context.cgContext.setFillColor(UIColor.red.cgColor)
            context.cgContext.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let photoPath = try await profile.uploadPhoto(userId: userId, jpeg: jpeg)
        let fixtureURL = try await profile.resolvePhotoURL(path: photoPath)
        defer { try? FileManager.default.removeItem(at: fixtureURL) }
        _ = try await profile.saveProfile(userId: userId, name: "Fresh Name", avatarPath: photoPath)
        context.presenter.onSceneBecameActive()
        await context.presenter.refreshTask?.value
        let updated = try #require(context.presenter.members.first)
        #expect(updated.displayName == "Fresh Name")
        #expect(updated.avatarPath == photoPath)
        #expect(updated.avatarFallbackText == "🌻")
        let resolvedURL = try #require(context.presenter.photoURL(for: updated))
        #expect(try Data(contentsOf: resolvedURL) == jpeg)
        #expect(!context.presenter.isOffline)
        context.presenter.onViewDisappear(delegate: CirclesDelegate())
    }

    private func makeContext(
        user: UserAuthInfo?,
        pendingStage: PendingEmailRegistration.Stage? = nil,
        profileService: (any ProfileServicing)? = nil,
        failCheers: Bool = false,
        failProgress: Bool = false
    ) throws -> CirclesAccessContext {
        let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
        let store = EmailRegistrationStore()
        if let pendingStage {
            try store.save(PendingEmailRegistration(
                userId: UserAuthInfo.mock().uid, email: "person@example.com", displayName: nil, stage: pendingStage
            ))
        }
        let emailService = MockEmailAuthService(user: user, store: store)
        let authManager = AuthManager(service: emailService)
        let userId = UserAuthInfo.mock().uid
        let service = MockSocialService(
            currentUserId: userId,
            circles: [CircleModel(circleId: "c1", name: "Circle", ownerId: userId, createdAt: .now, updatedAt: .now)],
            memberships: [CircleMembershipModel(membershipId: "m1", circleId: "c1", userId: userId, role: .owner, joinedAt: .now)],
            profileService: profileService
        )
        dependencies.container.register(EmailAuthServicing.self, service: emailService)
        dependencies.container.register(AuthManager.self, service: authManager)
        let managerService: any SocialService
        if failCheers || failProgress {
            managerService = CircleOptionalFailureService(service: service, failCheers: failCheers, failProgress: failProgress)
        } else {
            managerService = service
        }
        dependencies.container.register(SocialManager.self, service: SocialManager(service: managerService, profileService: profileService))
        let interactor = CoreInteractor(container: dependencies.container)
        let router = CirclesAccessRouter()
        return CirclesAccessContext(
            interactor: interactor, emailService: emailService, authManager: authManager, service: service,
            presenter: CirclesPresenter(interactor: interactor, router: router), router: router
        )
    }
}

@MainActor
private struct CirclesAccessContext {
    let interactor: CoreInteractor
    let emailService: MockEmailAuthService
    let authManager: AuthManager
    let service: MockSocialService
    let presenter: CirclesPresenter
    let router: CirclesAccessRouter
}

@MainActor
private final class CirclesAccessRouter: CirclesRouter {
    var router: AnyRouter { fatalError("Routing storage is unused by this test double") }
    var signupDelegate: SignUpDelegate?
    var signInCount = 0
    var signInCompletion: (() -> Void)?

    func showSignUpView(delegate: SignUpDelegate) { signupDelegate = delegate }
    func showCirclesSignInView(onDidSignIn: (() -> Void)?) {
        signInCount += 1
        signInCompletion = onDidSignIn
    }
}

@MainActor
private final class CircleOptionalFailureService: SocialService {
    private let service: MockSocialService
    private let failCheers: Bool
    private let failProgress: Bool

    init(service: MockSocialService, failCheers: Bool, failProgress: Bool) {
        self.service = service
        self.failCheers = failCheers
        self.failProgress = failProgress
    }

    func fetchCircles(userId: String) async throws -> [CircleModel] { try await service.fetchCircles(userId: userId) }
    func fetchMembers(circleId: String) async throws -> [CircleMemberModel] { try await service.fetchMembers(circleId: circleId) }
    func fetchCircleProgress(circleId: String) async throws -> [CircleMemberProgressModel] {
        if failProgress { throw SocialServiceError.persistenceFailed("Progress unavailable") }
        return try await service.fetchCircleProgress(circleId: circleId)
    }
    func fetchCheers(localDate: LocalDay) async throws -> [CheerModel] {
        if failCheers { throw SocialServiceError.persistenceFailed("Cheers unavailable") }
        return try await service.fetchCheers(localDate: localDate)
    }
    func updateDisplayName(_ name: String, userId: String) async throws { try await service.updateDisplayName(name, userId: userId) }
    func createCircle(name: String, ownerId: String) async throws -> CircleModel { try await service.createCircle(name: name, ownerId: ownerId) }
    func updateCircle(circleId: String, name: String) async throws -> CircleModel { try await service.updateCircle(circleId: circleId, name: name) }
    func deleteCircle(circleId: String) async throws { try await service.deleteCircle(circleId: circleId) }
    func createInvite(circleId: String, createdBy: String, expiresAt: Date) async throws -> CircleInviteModel {
        try await service.createInvite(circleId: circleId, createdBy: createdBy, expiresAt: expiresAt)
    }
    func revokeInvite(inviteId: String) async throws { try await service.revokeInvite(inviteId: inviteId) }
    func acceptInvite(code: String) async throws -> String { try await service.acceptInvite(code: code) }
    func leaveCircle(circleId: String, userId: String) async throws { try await service.leaveCircle(circleId: circleId, userId: userId) }
    func removeMember(circleId: String, userId: String) async throws { try await service.removeMember(circleId: circleId, userId: userId) }
    func publishProgress(userId: String, localDay: LocalDay, plannedSessions: Int, completedSessions: Int) async throws {
        try await service.publishProgress(userId: userId, localDay: localDay, plannedSessions: plannedSessions, completedSessions: completedSessions)
    }
    func sendCheer(_ kind: CheerKind, senderId: String, recipientId: String, localDate: LocalDay) async throws {
        try await service.sendCheer(kind, senderId: senderId, recipientId: recipientId, localDate: localDate)
    }
    func cheerStream() -> AsyncStream<CheerModel> { service.cheerStream() }
    func updateFocusStatus(_ status: CircleFocusStatus, userId: String, circleId: String) async {
        await service.updateFocusStatus(status, userId: userId, circleId: circleId)
    }
    func focusStatusStream(circleId: String) -> AsyncStream<[CircleFocusStatusEntry]> { service.focusStatusStream(circleId: circleId) }
    func stopFocusStatus(circleId: String) async { await service.stopFocusStatus(circleId: circleId) }
}
