import Foundation
import Observation
import SwiftfulAuthenticating

/// A shared local session for Mock builds. Never contacts a remote auth provider.
@Observable
@MainActor
final class MockEmailAuthService: EmailAuthServicing, AuthService {
    private(set) var authenticatedUser: UserAuthInfo?
    private let store: EmailRegistrationStore
    private let now: () -> Date
    private let sessionDefaults: UserDefaults?
    static let sessionKey = "tyfe.ui-tests.welcome-session"
    @ObservationIgnored private var listeners: [UUID: AsyncStream<UserAuthInfo?>.Continuation] = [:]

    init(
        user: UserAuthInfo? = nil,
        store: EmailRegistrationStore = EmailRegistrationStore(),
        sessionDefaults: UserDefaults? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        self.authenticatedUser = user
        self.store = store
        self.now = now
        self.sessionDefaults = sessionDefaults
    }

    var pendingRegistration: PendingEmailRegistration? { store.pending }

    func restoreRegistration() async throws -> PendingEmailRegistration? {
        guard let pending = store.pending else { return nil }
        try checkIdentity(pending)
        return pending
    }

    func beginRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration {
        guard let user = authenticatedUser else { throw EmailAuthError.sessionChanged }
        guard user.isAnonymous else { throw EmailAuthError.alreadySignedIn }
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard EmailCredentialValidator.isValidEmail(email) else { throw EmailAuthError.invalidEmail }
        if let pending = store.pending {
            try checkIdentity(pending)
            guard pending.stage == .details || pending.stage == .verification else { throw EmailAuthError.invalidStage }
            guard pending.resendSecondsRemaining(at: now()) == 0 else { throw EmailAuthError.rateLimited }
        }
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = PendingEmailRegistration(
            userId: user.uid,
            email: email,
            displayName: name?.isEmpty == false ? name : nil,
            stage: .verification,
            lastSentAt: now()
        )
        try store.save(pending)
        return pending
    }

    func verifyRegistrationCode(_ code: String) async throws -> PendingEmailRegistration {
        var pending = try requiredPending(stage: .verification)
        guard code == "123456" else { throw EmailAuthError.invalidCode }
        pending.stage = .password
        try store.save(pending)
        publish(makeUser(pending))
        return pending
    }

    func resendRegistrationCode() async throws -> PendingEmailRegistration {
        var pending = try requiredPending(stage: .verification)
        guard pending.resendSecondsRemaining(at: now()) == 0 else { throw EmailAuthError.rateLimited }
        pending.lastSentAt = now()
        try store.save(pending)
        return pending
    }

    func finishRegistration(password: String) async throws -> UserAuthInfo {
        guard var pending = store.pending,
              pending.stage == .password || pending.stage == .profile else { throw EmailAuthError.invalidStage }
        try checkIdentity(pending)
        if pending.stage == .password {
            guard EmailCredentialValidator.isValidPassword(password) else { throw EmailAuthError.weakPassword }
            pending.stage = .profile
            try store.save(pending)
        }
        let user = makeUser(pending)
        publish(user)
        return user
    }

    func acknowledgeRegistrationComplete() throws {
        _ = try requiredPending(stage: .profile)
        try store.save(nil)
    }

    func resetRegistrationAfterSignOut() throws { try store.save(nil) }

    func signIn(email: String, password: String) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        guard EmailCredentialValidator.isValidEmail(email), !password.isEmpty else { throw EmailAuthError.invalidCredentials }
        let user = UserAuthInfo(
            uid: authenticatedUser?.email == email ? authenticatedUser?.uid ?? "mock_email_user" : "mock_email_user",
            email: email,
            isAnonymous: false,
            authProviders: [.email],
            displayName: authenticatedUser?.email == email ? authenticatedUser?.displayName : nil,
            creationDate: now(),
            lastSignInDate: now()
        )
        if store.pending?.userId != user.uid { try store.save(nil) }
        publish(user)
        return (user, false)
    }

    func getAuthenticatedUser() -> UserAuthInfo? { authenticatedUser }

    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            let id = UUID()
            listeners[id] = continuation
            continuation.yield(authenticatedUser)
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in self?.listeners[id] = nil }
            }
        }
    }

    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        guard case .anonymous = option else { throw EmailAuthError.notConfigured }
        if let user = authenticatedUser { return (user, false) }
        let user = UserAuthInfo.mock(isAnonymous: true)
        publish(user)
        return (user, true)
    }

    func signOut() throws {
        try store.save(nil)
        publish(nil)
    }

    func deleteAccount() async throws {
        try signOut()
    }

    func deleteAccountWithReauthentication(
        option _: SignInOption,
        revokeToken _: Bool,
        performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void
    ) async throws {
        try await performDeleteActionsBeforeAuthIsDeleted()
        try signOut()
    }

    private func requiredPending(stage: PendingEmailRegistration.Stage) throws -> PendingEmailRegistration {
        guard let pending = store.pending, pending.stage == stage else { throw EmailAuthError.invalidStage }
        try checkIdentity(pending)
        return pending
    }

    private func checkIdentity(_ pending: PendingEmailRegistration) throws {
        guard authenticatedUser?.uid == pending.userId else {
            try store.save(nil)
            throw EmailAuthError.sessionChanged
        }
    }

    private func makeUser(_ pending: PendingEmailRegistration) -> UserAuthInfo {
        UserAuthInfo(
            uid: pending.userId,
            email: pending.email,
            isAnonymous: false,
            authProviders: [.email],
            displayName: pending.displayName,
            creationDate: authenticatedUser?.creationDate ?? now(),
            lastSignInDate: now()
        )
    }

    private func publish(_ user: UserAuthInfo?) {
        authenticatedUser = user
        if let user, let data = try? JSONEncoder().encode(user) {
            sessionDefaults?.set(data, forKey: Self.sessionKey)
        } else {
            sessionDefaults?.removeObject(forKey: Self.sessionKey)
        }
        for continuation in listeners.values { continuation.yield(user) }
    }
}
