import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct MockEmailAuthServiceTests {
    @Test func registrationUpgradesGuestWithoutChangingIdentity() async throws {
        let guest = UserAuthInfo(uid: "guest-id", isAnonymous: true, creationDate: .distantPast)
        let service = MockEmailAuthService(user: guest)
        let pending = try await service.beginRegistration(
            email: "  person@example.com  ", displayName: "  Ada  "
        )
        #expect(pending.email == "person@example.com")
        #expect(pending.displayName == "Ada")
        #expect(pending.stage == .verification)
        #expect(service.authenticatedUser?.isAnonymous == true)

        _ = try await service.verifyRegistrationCode("123456")
        let user = try await service.finishRegistration(password: "secret123")
        #expect(user.uid == guest.uid)
        #expect(user.creationDate == guest.creationDate)
        #expect(!user.isAnonymous)
        #expect(user.authProviders == [.email])
        #expect(user.displayName == "Ada")
        #expect(service.pendingRegistration?.stage == .profile)

        try service.acknowledgeRegistrationComplete()
        #expect(service.pendingRegistration == nil)
        #expect(service.getAuthenticatedUser()?.uid == guest.uid)
    }

    @Test func passwordCannotBeSetBeforeVerification() async throws {
        let service = MockEmailAuthService(user: .mock(isAnonymous: true))
        _ = try await service.beginRegistration(email: "person@example.com", displayName: "  ")
        #expect(service.pendingRegistration?.displayName == nil)
        await #expect(throws: EmailAuthError.invalidStage) {
            try await service.finishRegistration(password: "secret123")
        }
    }

    @Test func invalidCodeLeavesGuestAndRecoveryStateIntact() async throws {
        let service = MockEmailAuthService(user: .mock(isAnonymous: true))
        _ = try await service.beginRegistration(email: "person@example.com", displayName: nil)
        await #expect(throws: EmailAuthError.invalidCode) {
            try await service.verifyRegistrationCode("111111")
        }
        #expect(service.pendingRegistration?.stage == .verification)
        #expect(service.authenticatedUser?.isAnonymous == true)
    }

    @Test func resendAndEmailCorrectionRespectCooldown() async throws {
        let clock = RegistrationTestClock()
        let service = MockEmailAuthService(user: .mock(isAnonymous: true), now: { clock.date })
        _ = try await service.beginRegistration(email: "typo@example.com", displayName: nil)
        await #expect(throws: EmailAuthError.rateLimited) { try await service.resendRegistrationCode() }
        clock.date = clock.date.addingTimeInterval(60)
        let corrected = try await service.beginRegistration(email: "person@example.com", displayName: nil)
        #expect(corrected.email == "person@example.com")
        #expect(corrected.resendSecondsRemaining(at: clock.date) == 60)
        clock.date = clock.date.addingTimeInterval(60)
        let resent = try await service.resendRegistrationCode()
        #expect(resent.resendSecondsRemaining(at: clock.date) == 60)
    }

    @Test func profileRetryDoesNotRequireAnotherPassword() async throws {
        let service = MockEmailAuthService(user: .mock(isAnonymous: true))
        _ = try await service.beginRegistration(email: "person@example.com", displayName: nil)
        _ = try await service.verifyRegistrationCode("123456")
        let first = try await service.finishRegistration(password: "secret123")
        let retried = try await service.finishRegistration(password: "")
        #expect(retried.uid == first.uid)
        #expect(service.pendingRegistration?.stage == .profile)
    }

    @Test func restorationRejectsAnotherGuestIdentity() async throws {
        let store = EmailRegistrationStore()
        let original = MockEmailAuthService(user: UserAuthInfo(uid: "original", isAnonymous: true), store: store)
        _ = try await original.beginRegistration(email: "person@example.com", displayName: nil)
        let replacement = MockEmailAuthService(user: UserAuthInfo(uid: "other", isAnonymous: true), store: store)
        await #expect(throws: EmailAuthError.sessionChanged) { try await replacement.restoreRegistration() }
        #expect(store.pending == nil)
    }

    @Test func signInPublishesTheSameSessionUsedByAuthManager() async throws {
        let service = MockEmailAuthService()
        let (user, isNewUser) = try await service.signIn(email: "person@example.com", password: "secret123")
        #expect(service.getAuthenticatedUser()?.uid == user.uid)
        #expect(service.authenticatedUser?.email == user.email)
        #expect(!isNewUser)
        try service.signOut()
        #expect(service.authenticatedUser == nil)
    }
}

@MainActor
private final class RegistrationTestClock {
    var date = Date(timeIntervalSince1970: 1_700_000_000)
}
