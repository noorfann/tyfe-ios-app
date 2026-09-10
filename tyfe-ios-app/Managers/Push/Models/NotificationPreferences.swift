import Foundation

struct NotificationPreferences: Codable, Equatable, Sendable {
    var planRemindersEnabled: Bool
    var focusCompletionEnabled: Bool
    var rewardExpiryEnabled: Bool
    var quietHours: NotificationQuietHours?

    static let `default` = Self(
        planRemindersEnabled: true,
        focusCompletionEnabled: true,
        rewardExpiryEnabled: true,
        quietHours: nil
    )
}
