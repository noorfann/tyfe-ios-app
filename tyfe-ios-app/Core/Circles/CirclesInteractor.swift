import SwiftUI

@MainActor
protocol CirclesInteractor: GlobalInteractor {
    var currentAuthUserId: String? { get }
    var socialCircles: [CircleModel] { get }
    var socialCheers: [CheerModel] { get }
    var socialFocusStatuses: [String: [CircleFocusStatusEntry]] { get }
    var socialBlockedUserIds: [String] { get }
    var isSocialMigrationComplete: Bool { get }

    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func signOut() async throws
    func deleteAccount() async throws
    func migrateLocalToSocial() async throws

    func refreshSocialCircles(userId: String) async throws
    func createCircle(name: String, ownerId: String) async throws -> CircleModel
    func createCircleInvite(
        circleId: String,
        createdBy: String,
        expiresAt: Date
    ) async throws -> CircleInviteModel
    func acceptCircleInvite(code: String) async throws -> String
    func circleMembers(circleId: String) async throws -> [CircleMemberModel]
    func circleMemberProgress(circleId: String) async throws -> [CircleMemberProgressModel]
    func leaveCircle(circleId: String, userId: String) async throws
    func removeCircleMember(circleId: String, userId: String) async throws
    func sendCheer(_ kind: CheerKind, recipientId: String) async throws
    func refreshSocialCheers() async throws
    func startSocialRealtime(circleIds: [String])
    func stopSocialRealtime()
    func blockSocialUser(_ blockedId: String) async throws
    func unblockSocialUser(_ blockedId: String) async throws
    func refreshSocialBlockedUsers() async throws
    func setCircleSharingPaused(_ paused: Bool, circleId: String, userId: String) async throws
    func setGlobalSharingPaused(_ paused: Bool, userId: String) async throws
}

extension CoreInteractor: CirclesInteractor { }
