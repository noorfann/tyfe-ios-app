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
        client.auth.currentSession.map(Self.userAuthInfo(from:))
    }

    func addAuthenticatedUserListener() -> AsyncStream<UserAuthInfo?> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    continuation.yield(session.map(Self.userAuthInfo(from:)))
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
            let user = Self.userAuthInfo(from: session)
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

    private static func userAuthInfo(from session: Session) -> UserAuthInfo {
        let user = session.user
        let providers = (user.identities ?? []).compactMap { authProvider(for: $0.provider) }
        return UserAuthInfo(
            uid: user.id.uuidString,
            email: user.email,
            isAnonymous: user.isAnonymous,
            authProviders: providers,
            displayName: user.userMetadata["display_name"]?.stringValue,
            phoneNumber: user.phone,
            creationDate: user.createdAt,
            lastSignInDate: user.lastSignInAt
        )
    }

    private static func authProvider(for providerId: String) -> AuthProviderOption? {
        switch providerId {
        case "apple": return .apple
        case "google": return .google
        case "email": return .email
        case "phone": return .phone
        default: return nil
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
