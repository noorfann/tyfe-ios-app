import Foundation

enum AuthSignInSupport {
    static func isNewUser(createdAt: Date, lastSignInAt: Date?) -> Bool {
        guard let lastSignInAt else { return true }
        return abs(lastSignInAt.timeIntervalSince(createdAt)) < 10
    }
}
