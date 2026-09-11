import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialBlockTests {

    @Test func blockingAndRefreshingBlockedUsers() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))

        try await manager.blockUser("u2", blockerId: "u1")
        try await manager.refreshBlockedUserIds(userId: "u1")

        #expect(manager.blockedUserIds == ["u2"])
    }

    @Test func unblockingRemovesTheUser() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))

        try await manager.blockUser("u2", blockerId: "u1")
        try await manager.unblockUser("u2", blockerId: "u1")
        try await manager.refreshBlockedUserIds(userId: "u1")

        #expect(manager.blockedUserIds.isEmpty)
    }

    @Test func cannotBlockSelf() async {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))

        do {
            try await manager.blockUser("u1", blockerId: "u1")
            Issue.record("Expected notPermitted")
        } catch let error as SocialServiceError {
            #expect(error == .notPermitted)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func signOutClearsBlockedUsers() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))
        try await manager.blockUser("u2", blockerId: "u1")
        #expect(!manager.blockedUserIds.isEmpty)

        manager.signOut()

        #expect(manager.blockedUserIds.isEmpty)
    }
}
