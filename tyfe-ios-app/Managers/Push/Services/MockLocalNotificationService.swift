import Foundation

@MainActor
final class MockLocalNotificationService: LocalNotificationService {
    var status: NotificationAuthorizationStatus
    var authorizationResult: Bool
    private(set) var scheduledRequests: [LocalNotificationRequest]

    init(
        status: NotificationAuthorizationStatus = .authorized,
        authorizationResult: Bool = true,
        scheduledRequests: [LocalNotificationRequest] = []
    ) {
        self.status = status
        self.authorizationResult = authorizationResult
        self.scheduledRequests = scheduledRequests
    }

    func authorizationStatus() async -> NotificationAuthorizationStatus {
        status
    }

    func requestAuthorization() async throws -> Bool {
        if authorizationResult {
            status = .authorized
        }
        return authorizationResult
    }

    func schedule(_ request: LocalNotificationRequest) async throws {
        scheduledRequests.removeAll { $0.identifier == request.identifier }
        scheduledRequests.append(request)
    }

    func pendingRequestIdentifiers() async -> [String] {
        scheduledRequests.map(\.identifier)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        scheduledRequests.removeAll { identifiers.contains($0.identifier) }
    }
}
