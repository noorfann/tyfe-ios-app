import Foundation
import Observation

@MainActor
@Observable
final class SocialManager {
    @ObservationIgnored private let service: SocialService
    @ObservationIgnored private let logManager: LogManager?

    private(set) var circles: [CircleModel] = []
    private(set) var membersByCircle: [String: [CircleMemberModel]] = [:]
    private(set) var progressByCircle: [String: [CircleMemberProgressModel]] = [:]
    private(set) var cheers: [CheerModel] = []
    private(set) var blockedUserIds: [String] = []
    private(set) var hasMigratedToSocial = false
    private(set) var focusStatusesByCircle: [String: [CircleFocusStatusEntry]] = [:]
    private(set) var activeFocusCircleIds: Set<String> = []
    private(set) var globalSharingPaused = false
    private(set) var isLoading = false

    @ObservationIgnored private var cheerTask: Task<Void, Never>?
    @ObservationIgnored private var focusTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let userDefaults: UserDefaults?

    private static let migrationKey = "tyfe.social-migrated"

    init(
        service: SocialService,
        logManager: LogManager? = nil,
        userDefaults: UserDefaults? = nil
    ) {
        self.service = service
        self.logManager = logManager
        self.userDefaults = userDefaults
        self.hasMigratedToSocial = userDefaults?.bool(forKey: Self.migrationKey) ?? false
    }

    func refreshCircles(for userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        circles = try await service.fetchCircles(userId: userId)
    }

    func refreshProfile(userId: String) async throws {
        if let profile = try await service.fetchProfile(userId: userId) {
            globalSharingPaused = profile.sharingPaused
        }
    }

    func createCircle(name: String, ownerId: String) async throws -> CircleModel {
        logManager?.trackEvent(event: Event.createCircle(.start))
        do {
            let circle = try await service.createCircle(name: name, ownerId: ownerId)
            circles.append(circle)
            logManager?.trackEvent(event: Event.createCircle(.success))
            return circle
        } catch {
            logManager?.trackEvent(event: Event.createCircle(.fail(error)))
            throw error
        }
    }

    func createInvite(
        circleId: String,
        createdBy: String,
        expiresAt: Date
    ) async throws -> CircleInviteModel {
        logManager?.trackEvent(event: Event.createInvite(.start))
        do {
            let invite = try await service.createInvite(
                circleId: circleId,
                createdBy: createdBy,
                expiresAt: expiresAt
            )
            logManager?.trackEvent(event: Event.createInvite(.success))
            return invite
        } catch {
            logManager?.trackEvent(event: Event.createInvite(.fail(error)))
            throw error
        }
    }

    func revokeInvite(inviteId: String) async throws {
        try await service.revokeInvite(inviteId: inviteId)
    }

    func acceptInvite(code: String) async throws -> String {
        logManager?.trackEvent(event: Event.acceptInvite(.start))
        do {
            let circleId = try await service.acceptInvite(code: code)
            logManager?.trackEvent(event: Event.acceptInvite(.success))
            return circleId
        } catch {
            logManager?.trackEvent(event: Event.acceptInvite(.fail(error)))
            throw error
        }
    }

    @discardableResult
    func members(for circleId: String) async throws -> [CircleMemberModel] {
        let members = try await service.fetchMembers(circleId: circleId)
        membersByCircle[circleId] = members
        return members
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        logManager?.trackEvent(event: Event.leaveCircle(.start))
        do {
            try await service.leaveCircle(circleId: circleId, userId: userId)
            circles.removeAll { $0.circleId == circleId }
            membersByCircle[circleId] = nil
            logManager?.trackEvent(event: Event.leaveCircle(.success))
        } catch {
            logManager?.trackEvent(event: Event.leaveCircle(.fail(error)))
            throw error
        }
    }

    func removeMember(circleId: String, userId: String) async throws {
        logManager?.trackEvent(event: Event.removeMember(.start))
        do {
            try await service.removeMember(circleId: circleId, userId: userId)
            membersByCircle[circleId]?.removeAll { $0.userId == userId }
            logManager?.trackEvent(event: Event.removeMember(.success))
        } catch {
            logManager?.trackEvent(event: Event.removeMember(.fail(error)))
            throw error
        }
    }

    func updateDisplayName(_ name: String, userId: String) async throws {
        try await service.updateDisplayName(name, userId: userId)
    }

    func publishProgress(
        userId: String,
        localDay: LocalDay,
        plannedSessions: Int,
        completedSessions: Int
    ) async throws {
        logManager?.trackEvent(event: Event.publishProgress(.start))
        do {
            try await service.publishProgress(
                userId: userId,
                localDay: localDay,
                plannedSessions: plannedSessions,
                completedSessions: completedSessions
            )
            logManager?.trackEvent(event: Event.publishProgress(.success))
        } catch {
            logManager?.trackEvent(event: Event.publishProgress(.fail(error)))
            throw error
        }
    }

    @discardableResult
    func circleProgress(circleId: String) async throws -> [CircleMemberProgressModel] {
        let progress = try await service.fetchCircleProgress(circleId: circleId)
        progressByCircle[circleId] = progress
        return progress
    }

    func sendCheer(
        _ kind: CheerKind,
        senderId: String,
        recipientId: String,
        localDate: LocalDay
    ) async throws {
        logManager?.trackEvent(event: Event.sendCheer(.start))
        do {
            try await service.sendCheer(
                kind,
                senderId: senderId,
                recipientId: recipientId,
                localDate: localDate
            )
            logManager?.trackEvent(event: Event.sendCheer(.success))
        } catch {
            logManager?.trackEvent(event: Event.sendCheer(.fail(error)))
            throw error
        }
    }

    func refreshCheers(localDate: LocalDay) async throws {
        cheers = try await service.fetchCheers(localDate: localDate)
    }

    func startCheerDelivery() {
        guard cheerTask == nil else { return }
        let stream = service.cheerStream()
        cheerTask = Task { [weak self] in
            for await cheer in stream {
                self?.cheers.append(cheer)
            }
        }
    }

    func startFocusStatus(circleId: String) {
        guard focusTasks[circleId] == nil else { return }
        activeFocusCircleIds.insert(circleId)
        let stream = service.focusStatusStream(circleId: circleId)
        focusTasks[circleId] = Task { [weak self] in
            for await entries in stream {
                self?.focusStatusesByCircle[circleId] = entries
            }
        }
    }

    func updateFocusStatus(_ status: CircleFocusStatus, userId: String, circleId: String) async {
        await service.updateFocusStatus(status, userId: userId, circleId: circleId)
    }

    func updateFocusStatusForActiveCircles(_ status: CircleFocusStatus, userId: String) async {
        for circleId in activeFocusCircleIds {
            await service.updateFocusStatus(status, userId: userId, circleId: circleId)
        }
    }

    func stopRealtime() {
        cheerTask?.cancel()
        cheerTask = nil
        for task in focusTasks.values {
            task.cancel()
        }
        focusTasks = [:]
        activeFocusCircleIds = []
    }

    func blockUser(_ blockedId: String, blockerId: String) async throws {
        try await service.blockUser(blockedId, blockerId: blockerId)
        if !blockedUserIds.contains(blockedId) {
            blockedUserIds.append(blockedId)
        }
    }

    func unblockUser(_ blockedId: String, blockerId: String) async throws {
        try await service.unblockUser(blockedId, blockerId: blockerId)
        blockedUserIds.removeAll { $0 == blockedId }
    }

    func refreshBlockedUserIds(userId: String) async throws {
        blockedUserIds = try await service.fetchBlockedUserIds(userId: userId)
    }

    func markSocialMigrationComplete() {
        hasMigratedToSocial = true
        userDefaults?.set(true, forKey: Self.migrationKey)
    }

    func startRealtime(circleIds: [String]) {
        startCheerDelivery()
        setFocusCircles(Set(circleIds))
    }

    func setFocusCircles(_ circleIds: Set<String>) {
        for circleId in activeFocusCircleIds.subtracting(circleIds) {
            focusTasks[circleId]?.cancel()
            focusTasks[circleId] = nil
            focusStatusesByCircle[circleId] = nil
            activeFocusCircleIds.remove(circleId)
            Task { await service.stopFocusStatus(circleId: circleId) }
        }
        for circleId in circleIds where focusTasks[circleId] == nil {
            startFocusStatus(circleId: circleId)
        }
    }

    func setCircleSharingPaused(_ paused: Bool, circleId: String, userId: String) async throws {
        try await service.setCircleSharingPaused(paused, circleId: circleId, userId: userId)
    }

    func setGlobalSharingPaused(_ paused: Bool, userId: String) async throws {
        try await service.setGlobalSharingPaused(paused, userId: userId)
    }

    func signOut() {
        stopRealtime()
        circles = []
        membersByCircle = [:]
        progressByCircle = [:]
        cheers = []
        blockedUserIds = []
        focusStatusesByCircle = [:]
        globalSharingPaused = false
        isLoading = false
    }
}

enum SocialManagerEventStatus {
    case start
    case success
    case fail(Error)

    var name: String {
        switch self {
        case .start: return "Start"
        case .success: return "Success"
        case .fail: return "Fail"
        }
    }
}

extension SocialManager {
    enum Event: LoggableEvent {
        case createCircle(SocialManagerEventStatus)
        case createInvite(SocialManagerEventStatus)
        case acceptInvite(SocialManagerEventStatus)
        case leaveCircle(SocialManagerEventStatus)
        case removeMember(SocialManagerEventStatus)
        case publishProgress(SocialManagerEventStatus)
        case sendCheer(SocialManagerEventStatus)

        var eventName: String {
            "SocialMan_\(action)_\(status.name)"
        }

        var parameters: [String: Any]? {
            if case .fail(let error) = status {
                return ["error": error.localizedDescription]
            }
            return nil
        }

        var type: LogType {
            if case .fail = status {
                return .severe
            }
            return .analytic
        }

        private var action: String {
            switch self {
            case .createCircle: return "CreateCircle"
            case .createInvite: return "CreateInvite"
            case .acceptInvite: return "AcceptInvite"
            case .leaveCircle: return "LeaveCircle"
            case .removeMember: return "RemoveMember"
            case .publishProgress: return "PublishProgress"
            case .sendCheer: return "SendCheer"
            }
        }

        private var status: SocialManagerEventStatus {
            switch self {
            case .createCircle(let status),
                 .createInvite(let status),
                 .acceptInvite(let status),
                 .leaveCircle(let status),
                 .removeMember(let status),
                 .publishProgress(let status),
                 .sendCheer(let status):
                return status
            }
        }
    }
}
