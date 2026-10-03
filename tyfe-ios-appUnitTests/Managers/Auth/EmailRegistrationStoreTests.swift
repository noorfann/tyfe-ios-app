import Foundation
import Testing
@testable import tyfe_ios_app

@MainActor
struct EmailRegistrationStoreTests {
    @Test func recreatedStoreRestoresOnlyNonSecretRecoveryData() throws {
        let suite = "SignupTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let pending = PendingEmailRegistration(
            userId: "guest", email: "person@example.com", displayName: "Ada",
            stage: .password, lastSentAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        try EmailRegistrationStore(defaults: defaults).save(pending)
        let restored = EmailRegistrationStore(defaults: defaults)
        #expect(restored.pending == pending)
        let data = try #require(defaults.data(forKey: "tyfe.email-registration"))
        let fields = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(fields.keys) == ["user_id", "email", "display_name", "stage", "last_sent_at"])
        try restored.save(nil)
        #expect(EmailRegistrationStore(defaults: defaults).pending == nil)
    }

    @Test func resendCountdownHandlesExpiryAndClockChanges() {
        let sent = Date(timeIntervalSince1970: 1_700_000_000)
        let pending = PendingEmailRegistration(userId: "guest", email: "person@example.com", displayName: nil, stage: .verification, lastSentAt: sent)
        #expect(pending.resendSecondsRemaining(at: sent) == 60)
        #expect(pending.resendSecondsRemaining(at: sent.addingTimeInterval(59.1)) == 1)
        #expect(pending.resendSecondsRemaining(at: sent.addingTimeInterval(60)) == 0)
        #expect(pending.resendSecondsRemaining(at: sent.addingTimeInterval(-10)) == 60)
    }

    @Test func missingConfigurationNeverReturnsAnAuthenticatedSignup() async {
        let service = UnavailableEmailAuthService()
        #expect(service.authenticatedUser == nil)
        await #expect(throws: EmailAuthError.notConfigured) {
            try await service.beginRegistration(email: "person@example.com", displayName: nil)
        }
        await #expect(throws: EmailAuthError.notConfigured) { try await service.finishRegistration(password: "secret123") }
        await #expect(throws: EmailAuthError.notConfigured) { try await service.signIn(email: "person@example.com", password: "secret123") }
    }
}
