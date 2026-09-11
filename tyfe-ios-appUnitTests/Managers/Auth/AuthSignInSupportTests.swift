import Foundation
import Testing
@testable import tyfe_ios_app

struct AuthSignInSupportTests {

    @Test func newUserWhenLastSignInIsMissing() {
        #expect(AuthSignInSupport.isNewUser(createdAt: .now, lastSignInAt: nil))
    }

    @Test func newUserWhenCreationAndLastSignInAreClose() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        #expect(AuthSignInSupport.isNewUser(createdAt: createdAt, lastSignInAt: createdAt.addingTimeInterval(2)))
    }

    @Test func returningUserWhenLastSignInIsLater() {
        let createdAt = Date(timeIntervalSince1970: 1_000)
        #expect(!AuthSignInSupport.isNewUser(createdAt: createdAt, lastSignInAt: createdAt.addingTimeInterval(86_400)))
    }
}
