import Foundation

@MainActor
final class UnavailableEmailAuthService: EmailAuthServicing {
    func resetRegistrationAfterSignOut() throws { }
    var authenticatedUser: UserAuthInfo? { nil }
    var pendingRegistration: PendingEmailRegistration? { nil }

    func restoreRegistration() async throws -> PendingEmailRegistration? {
        throw EmailAuthError.notConfigured
    }

    func beginRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration {
        throw EmailAuthError.notConfigured
    }

    func verifyRegistrationCode(_ code: String) async throws -> PendingEmailRegistration {
        throw EmailAuthError.notConfigured
    }

    func resendRegistrationCode() async throws -> PendingEmailRegistration {
        throw EmailAuthError.notConfigured
    }

    func finishRegistration(password: String) async throws -> UserAuthInfo {
        throw EmailAuthError.notConfigured
    }

    func acknowledgeRegistrationComplete() throws {
        throw EmailAuthError.notConfigured
    }

    func signIn(email: String, password: String) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        throw EmailAuthError.notConfigured
    }
}
