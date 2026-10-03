import Foundation
import Observation

@MainActor
@Observable
final class SocialManager {
    @ObservationIgnored private let service: SocialService
    @ObservationIgnored private let logManager: LogManager?
    @ObservationIgnored private let profileService: (any ProfileServicing)?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var sessionGeneration = 0
    @ObservationIgnored private var activeUserId: String?
    @ObservationIgnored private var identityRevisions: [String: Int] = [:]
    private var resolvedPhotos: [String: ResolvedCirclePhoto] = [:]

    private(set) var circles: [CircleModel] = []
    private(set) var membersByCircle: [String: [CircleMemberModel]] = [:]
    private(set) var progressByCircle: [String: [CircleMemberProgressModel]] = [:]
    private(set) var cheers: [CheerModel] = []
    private(set) var pendingReceivedCheers: [CheerModel] = []
    private(set) var hasMigratedToSocial = false
    private(set) var focusStatusesByCircle: [String: [CircleFocusStatusEntry]] = [:]
    private(set) var activeFocusCircleIds: Set<String> = []
    private(set) var isLoading = false

    @ObservationIgnored private var cheerTask: Task<Void, Never>?
    @ObservationIgnored private var cheerRecipientId: String?
    @ObservationIgnored private var focusTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private let userDefaults: UserDefaults?

    private static let migrationKey = "tyfe.social-migrated"

    init(
        service: SocialService,
        logManager: LogManager? = nil,
        userDefaults: UserDefaults? = nil,
        profileService: (any ProfileServicing)? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.logManager = logManager
        self.userDefaults = userDefaults
        self.profileService = profileService
        self.now = now
        self.hasMigratedToSocial = userDefaults?.bool(forKey: Self.migrationKey) ?? false
    }

    func prepareAccount(userId: String) {
        let normalizedId = userId.lowercased()
        if let activeUserId, activeUserId != normalizedId { signOut() }
        activeUserId = normalizedId
    }

    func refreshCircles(for userId: String) async throws {
        prepareAccount(userId: userId)
        let generation = sessionGeneration
        isLoading = true
        defer { if generation == sessionGeneration { isLoading = false } }
        let fetchedCircles = try await service.fetchCircles(userId: userId)
        try requireCurrentSession(generation)
        circles = fetchedCircles
        let availableIds = Set(fetchedCircles.map(\.circleId))
        for circleId in membersByCircle.keys where !availableIds.contains(circleId) {
            identityRevisions[circleId] = (identityRevisions[circleId] ?? 0) + 1
        }
        membersByCircle = membersByCircle.filter { availableIds.contains($0.key) }
        progressByCircle = progressByCircle.filter { availableIds.contains($0.key) }
        pruneResolvedPhotos()
    }

    func createCircle(name: String, ownerId: String) async throws -> CircleModel {
        logManager?.trackEvent(event: Event.createCircle(.start))
        let generation = sessionGeneration
        do {
            let circle = try await service.createCircle(name: name, ownerId: ownerId)
            try requireCurrentSession(generation)
            circles.append(circle)
            logManager?.trackEvent(event: Event.createCircle(.success))
            return circle
        } catch {
            logManager?.trackEvent(event: Event.createCircle(.fail(error)))
            throw error
        }
    }

    func updateCircle(circleId: String, name: String) async throws -> CircleModel {
        logManager?.trackEvent(event: Event.updateCircle(.start))
        let generation = sessionGeneration
        do {
            let circle = try await service.updateCircle(circleId: circleId, name: name)
            try requireCurrentSession(generation)
            if let index = circles.firstIndex(where: { $0.circleId == circleId }) {
                circles[index] = circle
            }
            logManager?.trackEvent(event: Event.updateCircle(.success))
            return circle
        } catch {
            logManager?.trackEvent(event: Event.updateCircle(.fail(error)))
            throw error
        }
    }

    func deleteCircle(circleId: String) async throws {
        logManager?.trackEvent(event: Event.deleteCircle(.start))
        let generation = sessionGeneration
        do {
            try await service.deleteCircle(circleId: circleId)
            try requireCurrentSession(generation)
            identityRevisions[circleId] = (identityRevisions[circleId] ?? 0) + 1
            circles.removeAll { $0.circleId == circleId }
            membersByCircle[circleId] = nil
            progressByCircle[circleId] = nil
            focusStatusesByCircle[circleId] = nil
            pruneResolvedPhotos()
            if activeFocusCircleIds.remove(circleId) != nil {
                focusTasks[circleId]?.cancel()
                focusTasks[circleId] = nil
                Task { await service.stopFocusStatus(circleId: circleId) }
            }
            logManager?.trackEvent(event: Event.deleteCircle(.success))
        } catch {
            logManager?.trackEvent(event: Event.deleteCircle(.fail(error)))
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
        let generation = sessionGeneration
        let revision = (identityRevisions[circleId] ?? 0) + 1
        identityRevisions[circleId] = revision
        let members = try await service.fetchMembers(circleId: circleId)
        try requireCurrentIdentity(generation: generation, circleId: circleId, revision: revision)
        membersByCircle[circleId] = members
        pruneResolvedPhotos()
        try await resolvePhotos(for: members, generation: generation, circleId: circleId, revision: revision)
        try requireCurrentIdentity(generation: generation, circleId: circleId, revision: revision)
        return members
    }

    /// Signed URLs are memory-only and hidden once their five-minute lifetime ends.
    func photoURL(for member: CircleMemberModel) -> URL? {
        guard let photo = resolvedPhotos[member.userId.lowercased()],
              photo.path == member.avatarPath,
              photo.expiresAt > now() else { return nil }
        return photo.url
    }

    private func resolvePhotos(
        for members: [CircleMemberModel],
        generation: Int,
        circleId: String,
        revision: Int
    ) async throws {
        guard let profileService else { return }
        for member in members {
            try requireCurrentIdentity(generation: generation, circleId: circleId, revision: revision)
            let userId = member.userId.lowercased()
            guard let path = member.avatarPath else {
                resolvedPhotos[userId] = nil
                continue
            }
            if let existing = resolvedPhotos[userId],
               existing.path == path, existing.expiresAt.timeIntervalSince(now()) > 60 {
                continue
            }
            resolvedPhotos[userId] = nil
            do {
                let requestedAt = now()
                let url = try await profileService.resolvePhotoURL(path: path)
                try requireCurrentIdentity(generation: generation, circleId: circleId, revision: revision)
                resolvedPhotos[userId] = ResolvedCirclePhoto(
                    path: path, url: url, expiresAt: requestedAt.addingTimeInterval(300)
                )
            } catch {
                try requireCurrentIdentity(generation: generation, circleId: circleId, revision: revision)
                // Missing/deleted objects and denied reads retain the token/initial fallback.
            }
        }
    }

    private func pruneResolvedPhotos() {
        let paths = Dictionary(
            membersByCircle.values.flatMap { $0 }.compactMap { member in
                member.avatarPath.map { (member.userId.lowercased(), $0) }
            },
            uniquingKeysWith: { _, latest in latest }
        )
        resolvedPhotos = resolvedPhotos.filter { paths[$0.key] == $0.value.path }
    }

    private func requireCurrentSession(_ generation: Int) throws {
        guard generation == sessionGeneration, !Task.isCancelled else { throw CancellationError() }
    }

    private func requireCurrentIdentity(generation: Int, circleId: String, revision: Int) throws {
        try requireCurrentSession(generation)
        guard identityRevisions[circleId] == revision else { throw CancellationError() }
    }

    func leaveCircle(circleId: String, userId: String) async throws {
        logManager?.trackEvent(event: Event.leaveCircle(.start))
        let generation = sessionGeneration
        do {
            try await service.leaveCircle(circleId: circleId, userId: userId)
            try requireCurrentSession(generation)
            identityRevisions[circleId] = (identityRevisions[circleId] ?? 0) + 1
            circles.removeAll { $0.circleId == circleId }
            membersByCircle[circleId] = nil
            progressByCircle[circleId] = nil
            pruneResolvedPhotos()
            logManager?.trackEvent(event: Event.leaveCircle(.success))
        } catch {
            logManager?.trackEvent(event: Event.leaveCircle(.fail(error)))
            throw error
        }
    }

    func removeMember(circleId: String, userId: String) async throws {
        logManager?.trackEvent(event: Event.removeMember(.start))
        let generation = sessionGeneration
        do {
            try await service.removeMember(circleId: circleId, userId: userId)
            try requireCurrentSession(generation)
            identityRevisions[circleId] = (identityRevisions[circleId] ?? 0) + 1
            membersByCircle[circleId]?.removeAll { $0.userId == userId }
            pruneResolvedPhotos()
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
        let generation = sessionGeneration
        let progress = try await service.fetchCircleProgress(circleId: circleId)
        try requireCurrentSession(generation)
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
        let generation = sessionGeneration
        let fetchedCheers = try await service.fetchCheers(localDate: localDate)
        try requireCurrentSession(generation)
        cheers = fetchedCheers
    }

    func startCheerDelivery(recipientId: String) {
        let normalizedRecipientId = recipientId.lowercased()
        guard cheerTask == nil || cheerRecipientId != normalizedRecipientId else { return }
        cheerTask?.cancel()
        pendingReceivedCheers = []
        cheerRecipientId = normalizedRecipientId
        let stream = service.cheerStream()
        let generation = sessionGeneration
        cheerTask = Task { [weak self] in
            for await cheer in stream {
                guard let self, generation == self.sessionGeneration, !Task.isCancelled else { return }
                self.cheers.append(cheer)
                if cheer.recipientId.lowercased() == normalizedRecipientId {
                    self.pendingReceivedCheers.append(cheer)
                }
            }
        }
    }

    func consumePendingReceivedCheers() -> [CheerModel] {
        let receivedCheers = pendingReceivedCheers
        pendingReceivedCheers = []
        return receivedCheers
    }

    func discardPendingReceivedCheers() {
        pendingReceivedCheers = []
    }

    func startFocusStatus(circleId: String) {
        guard focusTasks[circleId] == nil else { return }
        activeFocusCircleIds.insert(circleId)
        let stream = service.focusStatusStream(circleId: circleId)
        let generation = sessionGeneration
        focusTasks[circleId] = Task { [weak self] in
            for await entries in stream {
                guard let self, generation == self.sessionGeneration, !Task.isCancelled else { return }
                self.focusStatusesByCircle[circleId] = entries
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
        cheerRecipientId = nil
        pendingReceivedCheers = []
        for task in focusTasks.values {
            task.cancel()
        }
        focusTasks = [:]
        activeFocusCircleIds = []
    }

    func markSocialMigrationComplete() {
        hasMigratedToSocial = true
        userDefaults?.set(true, forKey: Self.migrationKey)
    }

    func startRealtime(circleIds: [String], recipientId: String) {
        startCheerDelivery(recipientId: recipientId)
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

    func signOut() {
        sessionGeneration += 1
        activeUserId = nil
        identityRevisions = [:]
        resolvedPhotos = [:]
        stopRealtime()
        circles = []
        membersByCircle = [:]
        progressByCircle = [:]
        cheers = []
        pendingReceivedCheers = []
        focusStatusesByCircle = [:]
        isLoading = false
    }
}

private struct ResolvedCirclePhoto {
    let path: String
    let url: URL
    let expiresAt: Date
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
        case updateCircle(SocialManagerEventStatus)
        case deleteCircle(SocialManagerEventStatus)
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
            case .updateCircle: return "UpdateCircle"
            case .deleteCircle: return "DeleteCircle"
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
                 .updateCircle(let status),
                 .deleteCircle(let status),
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
