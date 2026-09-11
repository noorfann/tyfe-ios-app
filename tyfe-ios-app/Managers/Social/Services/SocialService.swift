import Foundation

@MainActor
protocol SocialService: Sendable {
    func fetchProfile(userId: String) async throws -> SocialProfileModel?
    func updateDisplayName(_ name: String, userId: String) async throws
    func createCircle(name: String, ownerId: String) async throws -> CircleModel
    func fetchCircles(userId: String) async throws -> [CircleModel]
    func fetchMembers(circleId: String) async throws -> [CircleMemberModel]
    func createInvite(circleId: String, createdBy: String, expiresAt: Date) async throws -> CircleInviteModel
    func revokeInvite(inviteId: String) async throws
    func acceptInvite(code: String) async throws -> String
    func leaveCircle(circleId: String, userId: String) async throws
    func removeMember(circleId: String, userId: String) async throws
    func publishProgress(
        userId: String,
        localDay: LocalDay,
        plannedSessions: Int,
        completedSessions: Int
    ) async throws
    func fetchCircleProgress(circleId: String) async throws -> [CircleMemberProgressModel]
    func sendCheer(_ kind: CheerKind, senderId: String, recipientId: String, localDate: LocalDay) async throws
    func fetchCheers(localDate: LocalDay) async throws -> [CheerModel]
    func cheerStream() -> AsyncStream<CheerModel>
    func updateFocusStatus(_ status: CircleFocusStatus, userId: String, circleId: String) async
    func focusStatusStream(circleId: String) -> AsyncStream<[CircleFocusStatusEntry]>
    func stopFocusStatus(circleId: String) async
    func blockUser(_ blockedId: String, blockerId: String) async throws
    func unblockUser(_ blockedId: String, blockerId: String) async throws
    func fetchBlockedUserIds(userId: String) async throws -> [String]
    func setCircleSharingPaused(_ paused: Bool, circleId: String, userId: String) async throws
    func setGlobalSharingPaused(_ paused: Bool, userId: String) async throws
}

enum SocialServiceError: LocalizedError, Equatable {
    case notConfigured
    case notAuthenticated
    case invalidName
    case circleNotFound
    case inviteNotFound
    case inviteNotRedeemable
    case alreadyMember
    case ownerCannotLeave
    case notPermitted
    case persistenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Social mode is not configured."
        case .notAuthenticated:
            return "Sign in is required for Circles."
        case .invalidName:
            return "Enter a Circle name."
        case .circleNotFound:
            return "That Circle could not be found."
        case .inviteNotFound:
            return "That invite code is not valid."
        case .inviteNotRedeemable:
            return "That invite code has expired or was already used."
        case .alreadyMember:
            return "You are already in that Circle."
        case .ownerCannotLeave:
            return "A Circle owner cannot leave. Remove the Circle instead."
        case .notPermitted:
            return "You do not have permission to do that."
        case .persistenceFailed(let reason):
            return reason
        }
    }
}
