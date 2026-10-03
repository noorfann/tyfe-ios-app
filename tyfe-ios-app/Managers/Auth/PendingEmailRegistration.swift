import Foundation

struct PendingEmailRegistration: Codable, Equatable, Sendable {
    enum Stage: String, Codable, Sendable {
        case details
        case verification
        case password
        case profile
    }

    let userId: String
    let email: String
    let displayName: String?
    var stage: Stage
    var lastSentAt: Date?

    func resendSecondsRemaining(at date: Date) -> Int {
        guard let lastSentAt else { return 0 }
        return min(60, max(0, Int(ceil(60 - date.timeIntervalSince(lastSentAt)))))
    }

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case email
        case displayName = "display_name"
        case stage
        case lastSentAt = "last_sent_at"
    }
}
