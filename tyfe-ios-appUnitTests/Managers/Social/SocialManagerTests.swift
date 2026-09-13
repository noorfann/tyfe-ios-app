import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct SocialManagerTests {

    @Test func creatingCircleSeedsOwnerMembership() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))

        let circle = try await manager.createCircle(name: "Family", ownerId: "u1")
        try await manager.refreshCircles(for: "u1")

        #expect(manager.circles.map(\.circleId) == [circle.circleId])

        let members = try await manager.members(for: circle.circleId)
        #expect(members.count == 1)
        #expect(members.first?.userId == "u1")
        #expect(members.first?.role == .owner)
    }

    @Test func rejectingEmptyCircleName() async {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))
        await assertThrows(.invalidName) {
            _ = try await manager.createCircle(name: "   ", ownerId: "u1")
        }
    }

    @Test func joiningViaOneTimeInvite() async throws {
        let manager = SocialManager(service: makeJoinableService(currentUserId: "u2"))
        let circleId = try await manager.acceptInvite(code: "JOINME12")

        #expect(circleId == "c1")
        let members = try await manager.members(for: "c1")
        #expect(members.contains { $0.userId == "u2" && $0.role == .member })
    }

    @Test func inviteCannotBeReused() async throws {
        let manager = SocialManager(service: makeJoinableService(currentUserId: "u2"))
        _ = try await manager.acceptInvite(code: "JOINME12")
        await assertThrows(.inviteNotRedeemable) {
            _ = try await manager.acceptInvite(code: "JOINME12")
        }
    }

    @Test func revokedInviteCannotBeUsed() async {
        let manager = SocialManager(service: MockSocialService(
            currentUserId: "u3",
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)],
            invites: [makeInvite(id: "i1", circleId: "c1", createdBy: "u1", code: "REVOKED1", revokedAt: .now)]
        ))
        await assertThrows(.inviteNotRedeemable) {
            _ = try await manager.acceptInvite(code: "REVOKED1")
        }
    }

    @Test func ownerCanRevokeInvite() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))
        let circle = try await manager.createCircle(name: "Office", ownerId: "u1")
        let invite = try await manager.createInvite(
            circleId: circle.circleId,
            createdBy: "u1",
            expiresAt: .now.addingTimeInterval(3_600)
        )
        try await manager.revokeInvite(inviteId: invite.inviteId)
    }

    @Test func unknownInviteCodeFails() async {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u2"))
        await assertThrows(.inviteNotFound) {
            _ = try await manager.acceptInvite(code: "NOPE1234")
        }
    }

    @Test func ownerCannotLeave() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))
        let circle = try await manager.createCircle(name: "Family", ownerId: "u1")
        await assertThrows(.ownerCannotLeave) {
            try await manager.leaveCircle(circleId: circle.circleId, userId: "u1")
        }
    }

    @Test func memberCanLeave() async throws {
        let service = makeJoinableService(currentUserId: "u2")
        let manager = SocialManager(service: service)
        _ = try await manager.acceptInvite(code: "JOINME12")
        #expect(service.memberUserIds(circleId: "c1").contains("u2"))

        try await manager.leaveCircle(circleId: "c1", userId: "u2")

        #expect(!service.memberUserIds(circleId: "c1").contains("u2"))
    }

    @Test func ownerCanRemoveMember() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1", memberships: [
            makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner),
            makeMembership(id: "m2", circleId: "c1", userId: "u2", role: .member)
        ]))

        try await manager.removeMember(circleId: "c1", userId: "u2")

        let members = try await manager.members(for: "c1")
        #expect(!members.contains { $0.userId == "u2" })
    }

    @Test func nonOwnerCannotRemoveMember() async {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u3", memberships: [
            makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner),
            makeMembership(id: "m2", circleId: "c1", userId: "u2", role: .member),
            makeMembership(id: "m3", circleId: "c1", userId: "u3", role: .member)
        ]))

        await assertThrows(.notPermitted) {
            try await manager.removeMember(circleId: "c1", userId: "u2")
        }
    }

    @Test func signOutClearsCachedState() async throws {
        let manager = SocialManager(service: MockSocialService(currentUserId: "u1"))
        let circle = try await manager.createCircle(name: "Family", ownerId: "u1")
        _ = try await manager.members(for: circle.circleId)
        #expect(!manager.circles.isEmpty)

        manager.signOut()

        #expect(manager.circles.isEmpty)
        #expect(manager.membersByCircle.isEmpty)
    }

    private func makeJoinableService(currentUserId: String) -> MockSocialService {
        MockSocialService(
            currentUserId: currentUserId,
            circles: [makeCircle(id: "c1", ownerId: "u1")],
            memberships: [makeMembership(id: "m1", circleId: "c1", userId: "u1", role: .owner)],
            invites: [makeInvite(id: "i1", circleId: "c1", createdBy: "u1", code: "JOINME12")]
        )
    }

    private func assertThrows(
        _ expected: SocialServiceError,
        _ operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected) but nothing was thrown")
        } catch let error as SocialServiceError {
            #expect(error == expected)
        } catch {
            Issue.record("Expected \(expected) but got \(error)")
        }
    }

    private func makeCircle(id: String, ownerId: String) -> CircleModel {
        CircleModel(circleId: id, name: "Circle", ownerId: ownerId, createdAt: .now, updatedAt: .now)
    }

    private func makeMembership(
        id: String,
        circleId: String,
        userId: String,
        role: CircleMemberRole
    ) -> CircleMembershipModel {
        CircleMembershipModel(
            membershipId: id,
            circleId: circleId,
            userId: userId,
            role: role,
            joinedAt: .now
        )
    }

    private func makeInvite(
        id: String,
        circleId: String,
        createdBy: String,
        code: String,
        revokedAt: Date? = nil
    ) -> CircleInviteModel {
        CircleInviteModel(
            inviteId: id,
            circleId: circleId,
            createdBy: createdBy,
            code: code,
            expiresAt: .now.addingTimeInterval(3_600),
            acceptedBy: nil,
            acceptedAt: nil,
            revokedAt: revokedAt,
            createdAt: .now
        )
    }
}
