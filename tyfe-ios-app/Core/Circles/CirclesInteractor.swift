import SwiftUI

@MainActor
protocol CirclesInteractor: GlobalInteractor {
    var currentAuthUserId: String? { get }
    var socialCircles: [CircleModel] { get }
    var socialCheers: [CheerModel] { get }
    var socialFocusStatuses: [String: [CircleFocusStatusEntry]] { get }
    var isSocialMigrationComplete: Bool { get }

    func signInAnonymously() async throws -> (user: UserAuthInfo, isNewUser: Bool)
    func migrateLocalToSocial() async throws

    func refreshSocialCircles(userId: String) async throws
    func createCircle(name: String, ownerId: String) async throws -> CircleModel
    func updateCircle(circleId: String, name: String) async throws -> CircleModel
    func deleteCircle(circleId: String) async throws
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
    func syncSocialRealtime() async
}

extension CoreInteractor: CirclesInteractor { }
