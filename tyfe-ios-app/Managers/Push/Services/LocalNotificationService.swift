import Foundation

@MainActor
protocol LocalNotificationService {
    func authorizationStatus() async -> NotificationAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func schedule(_ request: LocalNotificationRequest) async throws
    func pendingRequestIdentifiers() async -> [String]
    func removePendingRequests(withIdentifiers identifiers: [String])
}
