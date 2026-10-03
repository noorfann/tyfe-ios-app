#if !MOCK && canImport(Supabase)
import Foundation
import Supabase
import SwiftfulAuthenticating

@MainActor
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient
    private let profileService: any ProfileServicing
    private var guestSessionTask: Task<(user: UserAuthInfo, isNewUser: Bool), Error>?
    private var signOutTask: Task<Void, Never>?
    private var signOutGeneration = 0

    init(client: SupabaseClient, profileService: any ProfileServicing) {
        self.client = client
        self.profileService = profileService
    }

    func getAuthenticatedUser() -> UserAuthInfo? {
        guard signOutTask == nil else { return nil }
        return client.auth.currentSession.map { SupabaseUserAuthMapper.userAuthInfo(from: $0) }
    }

    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(signOutTask == nil ? session.map { SupabaseUserAuthMapper.userAuthInfo(from: $0) } : nil)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func signIn(option: SignInOption) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        switch option {
        case .anonymous:
            await waitForPendingSignOut()
            if let user = getAuthenticatedUser() { return (user, false) }
            if let guestSessionTask { return try await guestSessionTask.value }
            let task = Task {
                let session = try await client.auth.signInAnonymously()
                try Task.checkCancellation()
                let user = SupabaseUserAuthMapper.userAuthInfo(from: session)
                let isNewUser = AuthSignInSupport.isNewUser(
                    createdAt: session.user.createdAt,
                    lastSignInAt: session.user.lastSignInAt
                )
                return (user: user, isNewUser: isNewUser)
            }
            guestSessionTask = task
            defer { guestSessionTask = nil }
            return try await task.value
        case .apple:
            throw SupabaseAuthError.deferredProvider("Sign in with Apple")
        case .google:
            throw SupabaseAuthError.deferredProvider("Google sign-in")
        }
    }

    func signOut() throws {
        guestSessionTask?.cancel()
        signOutGeneration += 1
        signOutTask = Task { _ = try? await client.auth.signOut() }
    }

    func waitForPendingSignOut() async {
        let generation = signOutGeneration
        await signOutTask?.value
        if generation == signOutGeneration { signOutTask = nil }
    }

    func waitForSessionPreparation() async {
        await waitForPendingSignOut()
        // Email sign-in must follow guest bootstrap, so a late guest response cannot replace it.
        _ = try? await guestSessionTask?.value
    }

    func deleteAccount() async throws {
        guard let userId = getAuthenticatedUser()?.uid else { throw EmailAuthError.sessionChanged }
        let generation = signOutGeneration
        try await profileService.removeAllPhotos(userId: userId)
        try requireDeletionSession(userId: userId, generation: generation)
        try await client.rpc("delete_account").execute()
        try requireDeletionSession(userId: userId, generation: generation)
        try signOut()
    }

    func deleteAccountWithReauthentication(
        option _: SignInOption,
        revokeToken _: Bool,
        performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void
    ) async throws {
        guard let userId = getAuthenticatedUser()?.uid else { throw EmailAuthError.sessionChanged }
        let generation = signOutGeneration
        try await performDeleteActionsBeforeAuthIsDeleted()
        try requireDeletionSession(userId: userId, generation: generation)
        try await client.rpc("delete_account").execute()
        try requireDeletionSession(userId: userId, generation: generation)
        try signOut()
    }

    private func requireDeletionSession(userId: String, generation: Int) throws {
        guard signOutGeneration == generation, getAuthenticatedUser()?.uid == userId else {
            throw EmailAuthError.sessionChanged
        }
    }
}

enum SupabaseAuthError: LocalizedError {
    case deferredProvider(String)

    var errorDescription: String? {
        switch self {
        case .deferredProvider(let name):
            return "\(name) is not available yet."
        }
    }
}
#endif
