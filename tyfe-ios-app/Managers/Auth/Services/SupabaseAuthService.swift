#if !MOCK && canImport(Supabase)
import Foundation
import Supabase
import SwiftfulAuthenticating

@MainActor
final class SupabaseAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func getAuthenticatedUser() -> UserAuthInfo? {
        client.auth.currentSession.map { SupabaseUserAuthMapper.userAuthInfo(from: $0) }
    }

    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session.map { SupabaseUserAuthMapper.userAuthInfo(from: $0) })
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
            let session = try await client.auth.signInAnonymously()
            let user = SupabaseUserAuthMapper.userAuthInfo(from: session)
            let isNewUser = AuthSignInSupport.isNewUser(
                createdAt: session.user.createdAt,
                lastSignInAt: session.user.lastSignInAt
            )
            return (user, isNewUser)
        case .apple:
            throw SupabaseAuthError.deferredProvider("Sign in with Apple")
        case .google:
            throw SupabaseAuthError.deferredProvider("Google sign-in")
        }
    }

    func signOut() throws {
        Task { try? await client.auth.signOut() }
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_account").execute()
    }

    func deleteAccountWithReauthentication(
        option _: SignInOption,
        revokeToken _: Bool,
        performDeleteActionsBeforeAuthIsDeleted: () async throws -> Void
    ) async throws {
        try await performDeleteActionsBeforeAuthIsDeleted()
        try await client.rpc("delete_account").execute()
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
