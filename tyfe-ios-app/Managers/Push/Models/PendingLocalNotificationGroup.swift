import Foundation

struct PendingLocalNotificationGroup: Sendable {
    let identifierPrefix: String
    let kind: LocalNotificationKind
    let requests: [LocalNotificationRequest]
}
