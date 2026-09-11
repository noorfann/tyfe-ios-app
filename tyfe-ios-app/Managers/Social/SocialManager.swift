import Foundation
import Observation

@MainActor
@Observable
final class SocialManager {
    @ObservationIgnored private let service: SocialService
    @ObservationIgnored private let logManager: LogManager?

    private(set) var circles: [CircleModel] = []
    private(set) var membersByCircle: [String: [CircleMemberModel]] = [:]
    private(set) var isLoading = false

    init(service: SocialService, logManager: LogManager? = nil) {
        self.service = service
        self.logManager = logManager
    }

    func refreshCircles(for userId: String) async throws {
        isLoading = true
        defer { isLoading = false }
        circles = try await service.fetchCircles(userId: userId)
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

    func signOut() {
        circles = []
        membersByCircle = [:]
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
            }
        }

        private var status: SocialManagerEventStatus {
            switch self {
            case .createCircle(let status),
                 .createInvite(let status),
                 .acceptInvite(let status),
                 .leaveCircle(let status),
                 .removeMember(let status):
                return status
            }
        }
    }
}
