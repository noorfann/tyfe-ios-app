#if !MOCK && canImport(Supabase)
import Foundation
import Supabase
import SwiftfulAuthenticating

@MainActor
final class SupabaseEmailAuthService: EmailAuthServicing {
    private let client: SupabaseClient
    private let store: EmailRegistrationStore
    private let waitForAuthReset: @MainActor () async -> Void

    // This metadata is only a recovery hint, never an authorization claim.
    private static let passwordSavedKey = "tyfe_signup_password_saved"

    init(client: SupabaseClient, store: EmailRegistrationStore, waitForAuthReset: @escaping @MainActor () async -> Void = {}) {
        self.client = client
        self.store = store
        self.waitForAuthReset = waitForAuthReset
    }

    var authenticatedUser: UserAuthInfo? {
        client.auth.currentSession.map { SupabaseUserAuthMapper.userAuthInfo(from: $0) }
    }

    var pendingRegistration: PendingEmailRegistration? { store.pending }

    func restoreRegistration() async throws -> PendingEmailRegistration? {
        await waitForAuthReset()
        guard var pending = store.pending else { return nil }
        do {
            let session = try await client.auth.refreshSession()
            try checkIdentity(session.user, expectedId: pending.userId)
            if session.user.email?.lowercased() == pending.email.lowercased(),
               session.user.emailConfirmedAt != nil {
                if case .bool(true)? = session.user.userMetadata[Self.passwordSavedKey] {
                    pending.stage = .profile
                } else {
                    pending.stage = .password
                }
            } else if pending.stage == .password || pending.stage == .profile {
                throw EmailAuthError.sessionChanged
            } else if session.user.newEmail?.lowercased() == pending.email.lowercased() {
                pending.stage = .verification
                pending.lastSentAt = session.user.emailChangeSentAt ?? pending.lastSentAt
            }
            try store.save(pending)
            return pending
        } catch {
            throw Self.mapError(error)
        }
    }

    func beginRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailCredentialValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        do {
            let session = try await client.auth.session
            guard session.user.isAnonymous else { throw EmailAuthError.alreadySignedIn }
            if let pending = store.pending {
                try checkIdentity(session.user, expectedId: pending.userId)
                guard pending.stage == .details || pending.stage == .verification else {
                    throw EmailAuthError.invalidStage
                }
                guard pending.resendSecondsRemaining(at: .now) == 0 else { throw EmailAuthError.rateLimited }
            }
            let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
            var pending = PendingEmailRegistration(
                userId: session.user.id.uuidString,
                email: email,
                displayName: trimmedName?.isEmpty == false ? trimmedName : nil,
                stage: .details,
                lastSentAt: .now
            )
            // Save the intent before the write, so a lost response can be retried on the same UID.
            try store.save(pending)
            var metadata: [String: AnyJSON] = [Self.passwordSavedKey: .bool(false)]
            if let name = pending.displayName { metadata["display_name"] = .string(name) }
            let user = try await client.auth.update(user: UserAttributes(email: email, data: metadata))
            try checkIdentity(user, expectedId: pending.userId)
            pending.stage = .verification
            pending.lastSentAt = .now
            try store.save(pending)
            return pending
        } catch {
            throw Self.mapError(error)
        }
    }

    func verifyRegistrationCode(_ code: String) async throws -> PendingEmailRegistration {
        guard EmailCredentialValidator.isValidCode(code) else { throw EmailAuthError.invalidCode }
        // Verification may already have succeeded if its response was lost.
        if let restored = try await restoreRegistration(), restored.stage == .password || restored.stage == .profile {
            return restored
        }
        var pending = try requiredPending(stage: .verification)
        do {
            _ = try await checkedSession(for: pending)
            _ = try await client.auth.verifyOTP(email: pending.email, token: code, type: .emailChange)
            let session = try await client.auth.refreshSession()
            try checkIdentity(session.user, expectedId: pending.userId)
            guard session.user.email?.lowercased() == pending.email.lowercased(),
                  session.user.emailConfirmedAt != nil else { throw EmailAuthError.invalidCode }
            pending.stage = .password
            try store.save(pending)
            return pending
        } catch {
            throw Self.mapError(error)
        }
    }

    func resendRegistrationCode() async throws -> PendingEmailRegistration {
        var pending = try requiredPending(stage: .verification)
        guard pending.resendSecondsRemaining(at: .now) == 0 else { throw EmailAuthError.rateLimited }
        do {
            _ = try await checkedSession(for: pending)
            // Reserve the cooldown before sending, including when the response is lost.
            pending.lastSentAt = .now
            try store.save(pending)
            try await client.auth.resend(email: pending.email, type: .emailChange)
            _ = try await checkedSession(for: pending)
            return pending
        } catch {
            throw Self.mapError(error)
        }
    }

    func finishRegistration(password: String) async throws -> UserAuthInfo {
        guard let pending = store.pending,
              pending.stage == .password || pending.stage == .profile else { throw EmailAuthError.invalidStage }
        do {
            var session = try await checkedSession(for: pending)
            guard session.user.email?.lowercased() == pending.email.lowercased(),
                  session.user.emailConfirmedAt != nil else { throw EmailAuthError.confirmationRequired }
            if pending.stage == .password {
                guard EmailCredentialValidator.isValidPassword(password) else { throw EmailAuthError.weakPassword }
                let user = try await client.auth.update(user: UserAttributes(
                    password: password,
                    data: [Self.passwordSavedKey: .bool(true)]
                ))
                try checkIdentity(user, expectedId: pending.userId)
                var saved = pending
                saved.stage = .profile
                try store.save(saved)
                session = try await checkedSession(for: saved)
            }
            guard !session.user.isAnonymous else { throw EmailAuthError.confirmationRequired }
            return SupabaseUserAuthMapper.userAuthInfo(from: session)
        } catch {
            throw Self.mapError(error)
        }
    }

    func acknowledgeRegistrationComplete() throws {
        guard let pending = store.pending, pending.stage == .profile,
              let user = authenticatedUser, user.uid == pending.userId,
              !user.isAnonymous else { throw EmailAuthError.invalidStage }
        try store.save(nil)
    }

    func signIn(email: String, password: String) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        await waitForAuthReset()
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            if store.pending?.userId != session.user.id.uuidString { try store.save(nil) }
            return (SupabaseUserAuthMapper.userAuthInfo(from: session), false)
        } catch {
            throw Self.mapError(error)
        }
    }

    func resetRegistrationAfterSignOut() throws { try store.save(nil) }

    private func requiredPending(stage: PendingEmailRegistration.Stage) throws -> PendingEmailRegistration {
        guard let pending = store.pending, pending.stage == stage else { throw EmailAuthError.invalidStage }
        return pending
    }

    private func checkedSession(for pending: PendingEmailRegistration) async throws -> Session {
        let session = try await client.auth.session
        try checkIdentity(session.user, expectedId: pending.userId)
        return session
    }

    private func checkIdentity(_ user: User, expectedId: String) throws {
        guard user.id.uuidString == expectedId,
              client.auth.currentUser?.id.uuidString == expectedId else {
            try store.save(nil)
            throw EmailAuthError.sessionChanged
        }
    }

    private static func mapError(_ error: Error) -> Error {
        guard let authError = error as? AuthError else { return error }
        switch authError.errorCode {
        case .emailExists, .userAlreadyExists:
            return EmailAuthError.emailAlreadyInUse
        case .weakPassword:
            return EmailAuthError.weakPassword
        case .invalidCredentials:
            return EmailAuthError.invalidCredentials
        case .overEmailSendRateLimit, .overRequestRateLimit:
            return EmailAuthError.rateLimited
        case .emailNotConfirmed:
            return EmailAuthError.confirmationRequired
        case .otpExpired:
            return EmailAuthError.invalidCode
        default:
            return error
        }
    }
}
#endif
