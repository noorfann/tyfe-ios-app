import Foundation

extension CoreInteractor {

    // MARK: Social

    var currentAuthUserId: String? {
        auth?.uid
    }

    var canAccessCircles: Bool {
        auth?.isAnonymous == false && pendingEmailRegistration == nil
    }

    private func requireCirclesAccount() throws {
        guard canAccessCircles else { throw SocialServiceError.notAuthenticated }
    }

    var socialCircles: [CircleModel] {
        canAccessCircles ? socialManager.circles : []
    }

    func refreshSocialCircles(userId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.refreshCircles(for: userId)
    }

    @discardableResult
    func createCircle(name: String, ownerId: String) async throws -> CircleModel {
        try requireCirclesAccount()
        return try await socialManager.createCircle(name: name, ownerId: ownerId)
    }

    @discardableResult
    func updateCircle(circleId: String, name: String) async throws -> CircleModel {
        try requireCirclesAccount()
        return try await socialManager.updateCircle(circleId: circleId, name: name)
    }

    func deleteCircle(circleId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.deleteCircle(circleId: circleId)
    }

    @discardableResult
    func createCircleInvite(
        circleId: String,
        createdBy: String,
        expiresAt: Date
    ) async throws -> CircleInviteModel {
        try requireCirclesAccount()
        return try await socialManager.createInvite(circleId: circleId, createdBy: createdBy, expiresAt: expiresAt)
    }

    func revokeCircleInvite(inviteId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.revokeInvite(inviteId: inviteId)
    }

    @discardableResult
    func acceptCircleInvite(code: String) async throws -> String {
        try requireCirclesAccount()
        return try await socialManager.acceptInvite(code: code)
    }

    @discardableResult
    func circleMembers(circleId: String) async throws -> [CircleMemberModel] {
        try requireCirclesAccount()
        return try await socialManager.members(for: circleId)
    }

    func circlePhotoURL(for member: CircleMemberModel) -> URL? {
        canAccessCircles ? socialManager.photoURL(for: member) : nil
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.leaveCircle(circleId: circleId, userId: userId)
    }

    func removeCircleMember(circleId: String, userId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.removeMember(circleId: circleId, userId: userId)
    }

    func updateSocialDisplayName(_ name: String, userId: String) async throws {
        try requireCirclesAccount()
        try await socialManager.updateDisplayName(name, userId: userId)
    }

    func syncSharedProgress(for localDay: LocalDay? = nil) async {
        guard canAccessCircles, let userId = auth?.uid else { return }
        let day = localDay ?? todayManager.currentLocalDay
        let planned = todayManager.plannedUnitCount(.session, on: day)
        let completed = todayManager.completedSessionCount(on: day)
        try? await socialManager.publishProgress(
            userId: userId,
            localDay: day,
            plannedSessions: planned,
            completedSessions: completed
        )
    }

    func scheduleSharedProgressSync(for localDay: LocalDay? = nil) {
        Task { await syncSharedProgress(for: localDay) }
    }

    var circleProgressByCircle: [String: [CircleMemberProgressModel]] {
        canAccessCircles ? socialManager.progressByCircle : [:]
    }

    @discardableResult
    func circleMemberProgress(circleId: String) async throws -> [CircleMemberProgressModel] {
        try requireCirclesAccount()
        return try await socialManager.circleProgress(circleId: circleId)
    }

    var socialCheers: [CheerModel] {
        canAccessCircles ? socialManager.cheers : []
    }

    var pendingReceivedCheerCount: Int {
        canAccessCircles ? socialManager.pendingReceivedCheers.count : 0
    }

    func consumePendingReceivedCheers() -> [CheerModel] {
        guard canAccessCircles else { return [] }
        return socialManager.consumePendingReceivedCheers()
    }

    func discardPendingReceivedCheers() {
        socialManager.discardPendingReceivedCheers()
    }

    var socialFocusStatuses: [String: [CircleFocusStatusEntry]] {
        canAccessCircles ? socialManager.focusStatusesByCircle : [:]
    }

    func sendCheer(_ kind: CheerKind, recipientId: String) async throws {
        try requireCirclesAccount()
        guard let senderId = auth?.uid else { throw SocialServiceError.notAuthenticated }
        try await socialManager.sendCheer(
            kind,
            senderId: senderId,
            recipientId: recipientId,
            localDate: todayManager.currentLocalDay
        )
    }

    func refreshSocialCheers() async throws {
        try requireCirclesAccount()
        try await socialManager.refreshCheers(localDate: todayManager.currentLocalDay)
    }

    func startSocialRealtime(circleIds: [String]) {
        guard canAccessCircles, let recipientId = auth?.uid else {
            socialManager.stopRealtime()
            return
        }
        socialManager.startCheerDelivery(recipientId: recipientId)
        for circleId in circleIds {
            socialManager.startFocusStatus(circleId: circleId)
        }
    }

    func stopSocialRealtime() {
        socialManager.stopRealtime()
    }

    func syncSocialRealtime() async {
        guard canAccessCircles, let userId = auth?.uid else {
            socialManager.stopRealtime()
            return
        }
        if socialManager.circles.isEmpty {
            try? await socialManager.refreshCircles(for: userId)
        }
        guard canAccessCircles, auth?.uid == userId, !socialManager.circles.isEmpty else {
            socialManager.stopRealtime()
            return
        }
        socialManager.markSocialMigrationComplete()
        socialManager.startRealtime(
            circleIds: socialManager.circles.map(\.circleId),
            recipientId: userId
        )
        await updateSocialFocusStatus(activeFocusSession?.state == .running ? .focusing : .available)
    }

    func updateSocialFocusStatus(_ status: CircleFocusStatus) async {
        guard canAccessCircles, let userId = auth?.uid else { return }
        await socialManager.updateFocusStatusForActiveCircles(status, userId: userId.lowercased())
    }

    var isSocialMigrationComplete: Bool {
        socialManager.hasMigratedToSocial
    }

    func migrateLocalToSocial() async throws {
        try requireCirclesAccount()
        guard let userId = auth?.uid else { throw SocialServiceError.notAuthenticated }
        let day = todayManager.currentLocalDay
        let planned = todayManager.plannedUnitCount(.session, on: day)
        let completed = todayManager.completedSessionCount(on: day)
        try await socialManager.publishProgress(
            userId: userId,
            localDay: day,
            plannedSessions: planned,
            completedSessions: completed
        )
        socialManager.markSocialMigrationComplete()
    }
}
