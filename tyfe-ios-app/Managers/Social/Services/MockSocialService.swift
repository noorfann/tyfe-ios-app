import Foundation

@MainActor
final class MockSocialService: SocialService {
    private(set) var currentUserId: String
    private var profiles: [String: SocialProfileModel]
    private var circles: [CircleModel]
    private var memberships: [CircleMembershipModel]
    private var invites: [CircleInviteModel]
    private var snapshots: [String: [LocalDay: SharedProgressSnapshot]] = [:]
    private var cheers: [CheerModel] = []
    private var cheerCounter = 0
    private var cheerContinuations: [UUID: AsyncStream<CheerModel>.Continuation] = [:]
    private var focusStatuses: [String: [String: CircleFocusStatus]] = [:]
    private var focusContinuations: [String: [UUID: AsyncStream<[CircleFocusStatusEntry]>.Continuation]] = [:]
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
                avatarToken: nil
            )
        ]
        self.circles = circles
        self.memberships = memberships
        self.invites = invites
        self.circleCounter = circles.count
        self.membershipCounter = memberships.count
        self.inviteCounter = invites.count
    }

    func updateDisplayName(_ name: String, userId: String) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }
        guard userId == currentUserId else { throw SocialServiceError.notPermitted }
        profiles[userId] = SocialProfileModel(
            userId: userId,
            displayName: trimmed,
            avatarToken: profiles[userId]?.avatarToken
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
            joinedAt: now
        ))
        membershipCounter += 1
        return circle
    }

    func updateCircle(circleId: String, name: String) async throws -> CircleModel {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SocialServiceError.invalidName }
        guard currentUserIsOwner(of: circleId) else { throw SocialServiceError.notPermitted }
        guard let index = circles.firstIndex(where: { $0.circleId == circleId }) else {
            throw SocialServiceError.circleNotFound
        }
        let existing = circles[index]
        let updated = CircleModel(
            circleId: existing.circleId,
            name: trimmed,
            ownerId: existing.ownerId,
            createdAt: existing.createdAt,
            updatedAt: .now
        )
        circles[index] = updated
        return updated
    }

    func deleteCircle(circleId: String) async throws {
        guard currentUserIsOwner(of: circleId) else { throw SocialServiceError.notPermitted }
        circles.removeAll { $0.circleId == circleId }
        memberships.removeAll { $0.circleId == circleId }
        invites.removeAll { $0.circleId == circleId }
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

    func publishProgress(
        userId: String,
        localDay: LocalDay,
        plannedSessions: Int,
        completedSessions: Int
    ) async throws {
        guard userId == currentUserId else { throw SocialServiceError.notPermitted }
        snapshots[userId, default: [:]][localDay] = SharedProgressSnapshot(
            planned: max(plannedSessions, 0),
            completed: max(completedSessions, 0),
            updatedAt: .now
        )
    }

    func fetchCircleProgress(circleId: String) async throws -> [CircleMemberProgressModel] {
        guard currentUserIsMember(of: circleId) else { throw SocialServiceError.notPermitted }
        return memberships
            .filter { $0.circleId == circleId }
            .map { membership in
                let userSnapshots = snapshots[membership.userId] ?? [:]
                let latestDay = userSnapshots.keys.max { $0.startDate < $1.startDate }
                let latest = latestDay.flatMap { userSnapshots[$0] }
                let sevenDay = sevenDayCompleted(in: userSnapshots, latestDay: latestDay)
                let profile = profiles[membership.userId]
                return CircleMemberProgressModel(
                    circleId: circleId,
                    userId: membership.userId,
                    displayName: profile?.displayName ?? "Friend",
                    avatarToken: profile?.avatarToken,
                    isOwner: membership.role == .owner,
                    latestDate: latestDay?.socialDateString,
                    todayPlanned: latest?.planned ?? 0,
                    todayCompleted: latest?.completed ?? 0,
                    sevenDayCompleted: sevenDay,
                    cheersToday: 0,
                    progressUpdatedAt: latest?.updatedAt
                )
            }
    }

    func snapshotCount(userId: String) -> Int {
        snapshots[userId]?.count ?? 0
    }

    func sendCheer(
        _ kind: CheerKind,
        senderId: String,
        recipientId: String,
        localDate: LocalDay
    ) async throws {
        guard senderId == currentUserId, senderId != recipientId, sharesCircle(with: recipientId) else {
            throw SocialServiceError.notPermitted
        }
        cheerCounter += 1
        let cheer = CheerModel(
            cheerId: "mock-cheer-\(cheerCounter)",
            senderId: senderId,
            recipientId: recipientId,
            localDate: localDate.socialDateString,
            kind: kind,
            createdAt: .now
        )
        cheers.append(cheer)
        emitCheer(cheer)
    }

    func fetchCheers(localDate: LocalDay) async throws -> [CheerModel] {
        cheers.filter {
            $0.localDate == localDate.socialDateString
                && ($0.senderId == currentUserId || $0.recipientId == currentUserId)
        }
    }

    func cheerStream() -> AsyncStream<CheerModel> {
        AsyncStream { continuation in
            let id = UUID()
            cheerContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.cheerContinuations[id] = nil }
            }
        }
    }

    func seedCheer(_ cheer: CheerModel) {
        cheers.append(cheer)
        emitCheer(cheer)
    }

    func updateFocusStatus(_ status: CircleFocusStatus, userId: String, circleId: String) async {
        focusStatuses[circleId, default: [:]][userId] = status
        emitFocusStatuses(circleId: circleId)
    }

    func focusStatusStream(circleId: String) -> AsyncStream<[CircleFocusStatusEntry]> {
        AsyncStream { continuation in
            let id = UUID()
            focusContinuations[circleId, default: [:]][id] = continuation
            continuation.yield(focusEntries(circleId: circleId))
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.focusContinuations[circleId]?[id] = nil }
            }
        }
    }

    func stopFocusStatus(circleId: String) async {
        focusContinuations[circleId]?.values.forEach { $0.finish() }
        focusContinuations[circleId] = nil
        focusStatuses[circleId] = nil
    }

    private func emitCheer(_ cheer: CheerModel) {
        for continuation in cheerContinuations.values {
            continuation.yield(cheer)
        }
    }

    private func focusEntries(circleId: String) -> [CircleFocusStatusEntry] {
        (focusStatuses[circleId] ?? [:])
            .map { CircleFocusStatusEntry(userId: $0.key, status: $0.value) }
            .sorted { $0.userId < $1.userId }
    }

    private func emitFocusStatuses(circleId: String) {
        let entries = focusEntries(circleId: circleId)
        focusContinuations[circleId]?.values.forEach { $0.yield(entries) }
    }

    private func sevenDayCompleted(
        in userSnapshots: [LocalDay: SharedProgressSnapshot],
        latestDay: LocalDay?
    ) -> Int {
        guard let latestDay else { return 0 }
        let windowStart = latestDay.startDate.addingTimeInterval(-6 * 86_400)
        return userSnapshots
            .filter { day, _ in day.startDate >= windowStart && day.startDate <= latestDay.startDate }
            .values
            .reduce(0) { $0 + $1.completed }
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

private struct SharedProgressSnapshot {
    var planned: Int
    var completed: Int
    var updatedAt: Date
}
