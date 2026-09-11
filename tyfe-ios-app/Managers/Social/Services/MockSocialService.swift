import Foundation

@MainActor
final class MockSocialService: SocialService {
    private(set) var currentUserId: String
    private var profiles: [String: SocialProfileModel]
    private var circles: [CircleModel]
    private var memberships: [CircleMembershipModel]
    private var invites: [CircleInviteModel]
    private var circleCounter: Int
    private var membershipCounter: Int
    private var inviteCounter: Int

    private static let codeAlphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    init(
        currentUserId: String = "mock-user",
        profiles: [String: SocialProfileModel]? = nil,
        circles: [CircleModel] = [],
        memberships: [CircleMembershipModel] = [],
        invites: [CircleInviteModel] = []
    ) {
        self.currentUserId = currentUserId
        self.profiles = profiles ?? [
            currentUserId: SocialProfileModel(
                userId: currentUserId,
                displayName: "You",
                avatarToken: nil,
                sharingPaused: false
            )
        ]
        self.circles = circles
        self.memberships = memberships
        self.invites = invites
        self.circleCounter = circles.count
        self.membershipCounter = memberships.count
        self.inviteCounter = invites.count
    }

    func fetchProfile(userId: String) async throws -> SocialProfileModel? {
        if userId == currentUserId || sharesCircle(with: userId) {
            return profiles[userId]
        }
        return nil
    }

    func updateDisplayName(_ name: String, userId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }
        guard userId == currentUserId else { throw SocialServiceError.notPermitted }
        profiles[userId] = SocialProfileModel(
            userId: userId,
            displayName: trimmed,
            avatarToken: profiles[userId]?.avatarToken,
            sharingPaused: profiles[userId]?.sharingPaused ?? false
        )
    }

    func createCircle(name: String, ownerId: String) async throws -> CircleModel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }
        guard ownerId == currentUserId else { throw SocialServiceError.notPermitted }

        circleCounter += 1
        let now = Date()
        let circle = CircleModel(
            circleId: "mock-circle-\(circleCounter)",
            name: trimmed,
            ownerId: ownerId,
            createdAt: now,
            updatedAt: now
        )
        circles.append(circle)
        memberships.append(CircleMembershipModel(
            membershipId: "mock-membership-\(membershipCounter + 1)",
            circleId: circle.circleId,
            userId: ownerId,
            role: .owner,
            sharingPaused: false,
            joinedAt: now
        ))
        membershipCounter += 1
        return circle
    }

    func fetchCircles(userId: String) async throws -> [CircleModel] {
        let circleIds = Set(memberships.filter { $0.userId == userId }.map(\.circleId))
        return circles.filter { circleIds.contains($0.circleId) }
    }

    func fetchMembers(circleId: String) async throws -> [CircleMemberModel] {
        guard currentUserIsMember(of: circleId) else { throw SocialServiceError.notPermitted }
        return memberships
            .filter { $0.circleId == circleId }
            .map { membership in
                let profile = profiles[membership.userId]
                return CircleMemberModel(
                    userId: membership.userId,
                    displayName: profile?.displayName ?? "Friend",
                    avatarToken: profile?.avatarToken,
                    role: membership.role,
                    sharingPaused: membership.sharingPaused,
                    joinedAt: membership.joinedAt
                )
            }
    }

    func createInvite(circleId: String, createdBy: String, expiresAt: Date) async throws -> CircleInviteModel {
        guard createdBy == currentUserId, currentUserIsOwner(of: circleId) else {
            throw SocialServiceError.notPermitted
        }
        inviteCounter += 1
        let invite = CircleInviteModel(
            inviteId: "mock-invite-\(inviteCounter)",
            circleId: circleId,
            createdBy: createdBy,
            code: uniqueCode(),
            expiresAt: expiresAt,
            acceptedBy: nil,
            acceptedAt: nil,
            revokedAt: nil,
            createdAt: .now
        )
        invites.append(invite)
        return invite
    }

    func revokeInvite(inviteId: String) async throws {
        guard let index = invites.firstIndex(where: { $0.inviteId == inviteId }),
              currentUserIsOwner(of: invites[index].circleId) else {
            throw SocialServiceError.notPermitted
        }
        let invite = invites[index]
        invites[index] = CircleInviteModel(
            inviteId: invite.inviteId,
            circleId: invite.circleId,
            createdBy: invite.createdBy,
            code: invite.code,
            expiresAt: invite.expiresAt,
            acceptedBy: invite.acceptedBy,
            acceptedAt: invite.acceptedAt,
            revokedAt: .now,
            createdAt: invite.createdAt
        )
    }

    func acceptInvite(code: String) async throws -> String {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard let index = invites.firstIndex(where: { $0.code == normalized }) else {
            throw SocialServiceError.inviteNotFound
        }
        let invite = invites[index]
        guard invite.isRedeemable else { throw SocialServiceError.inviteNotRedeemable }
        guard !currentUserIsMember(of: invite.circleId) else { throw SocialServiceError.alreadyMember }

        memberships.append(CircleMembershipModel(
            membershipId: "mock-membership-\(membershipCounter + 1)",
            circleId: invite.circleId,
            userId: currentUserId,
            role: .member,
            sharingPaused: false,
            joinedAt: .now
        ))
        membershipCounter += 1
        invites[index] = CircleInviteModel(
            inviteId: invite.inviteId,
            circleId: invite.circleId,
            createdBy: invite.createdBy,
            code: invite.code,
            expiresAt: invite.expiresAt,
            acceptedBy: currentUserId,
            acceptedAt: .now,
            revokedAt: invite.revokedAt,
            createdAt: invite.createdAt
        )
        return invite.circleId
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        guard userId == currentUserId else { throw SocialServiceError.notPermitted }
        guard let membership = memberships.first(where: { $0.circleId == circleId && $0.userId == userId }) else {
            throw SocialServiceError.circleNotFound
        }
        guard membership.role != .owner else { throw SocialServiceError.ownerCannotLeave }
        memberships.removeAll { $0.membershipId == membership.membershipId }
    }

    func removeMember(circleId: String, userId: String) async throws {
        guard currentUserIsOwner(of: circleId), userId != currentUserId else {
            throw SocialServiceError.notPermitted
        }
        memberships.removeAll { $0.circleId == circleId && $0.userId == userId }
    }

    func memberUserIds(circleId: String) -> [String] {
        memberships.filter { $0.circleId == circleId }.map(\.userId)
    }

    private func currentUserIsMember(of circleId: String) -> Bool {
        memberships.contains { $0.circleId == circleId && $0.userId == currentUserId }
    }

    private func currentUserIsOwner(of circleId: String) -> Bool {
        memberships.contains { $0.circleId == circleId && $0.userId == currentUserId && $0.role == .owner }
    }

    private func sharesCircle(with userId: String) -> Bool {
        let myCircleIds = Set(memberships.filter { $0.userId == currentUserId }.map(\.circleId))
        return memberships.contains { $0.userId == userId && myCircleIds.contains($0.circleId) }
    }

    private func uniqueCode() -> String {
        var code = String((0..<8).map { _ in Self.codeAlphabet.randomElement()! })
        while invites.contains(where: { $0.code == code }) {
            code = String((0..<8).map { _ in Self.codeAlphabet.randomElement()! })
        }
        return code
    }
}
