import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct MockEmailAuthServiceTests {

    @Test func registerReturnsPermanentEmailUser() async throws {
        let service = MockEmailAuthService()

        let (user, isNewUser) = try await service.register(
            email: "person@example.com",
            password: "secret123",
            displayName: "  Ada  "
        )

        #expect(user.email == "person@example.com")
        #expect(user.isAnonymous == false)
        #expect(user.authProviders == [.email])
        #expect(user.displayName == "Ada")
        #expect(isNewUser)
    }

    @Test func registerWithoutNameLeavesDisplayNameNil() async throws {
        let service = MockEmailAuthService()

        let (user, _) = try await service.register(
            email: "person@example.com",
            password: "secret123",
            displayName: "   "
        )

        #expect(user.displayName == nil)
    }

    @Test func signInReturnsExistingUser() async throws {
        let service = MockEmailAuthService()

        let (user, isNewUser) = try await service.signIn(
            email: "person@example.com",
            password: "secret123"
        )

        #expect(user.email == "person@example.com")
        #expect(user.isAnonymous == false)
        #expect(user.authProviders == [.email])
        #expect(!isNewUser)
    }
}
