//
//  SupabaseEmailAuthService.swift
//  tyfe-ios-app
//
//  Live email + password auth backed by Supabase's GoTrue endpoint.
//

#if !MOCK && canImport(Supabase)
import Foundation
import Supabase
import SwiftfulAuthenticating

@MainActor
final class SupabaseEmailAuthService: EmailAuthServicing {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func register(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password,
                data: Self.metadata(displayName: displayName)
            )

            // When email confirmation is enabled GoTrue returns the user without a
            // session, so the account exists but cannot sign in until confirmed.
            guard let session = response.session else {
                throw EmailAuthError.confirmationRequired
            }

            return (SupabaseUserAuthMapper.userAuthInfo(from: session), true)
        } catch let error as EmailAuthError {
            throw error
        } catch {
            throw Self.mapError(error)
        }
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        do {
            let session = try await client.auth.signIn(email: email, password: password)
            return (SupabaseUserAuthMapper.userAuthInfo(from: session), false)
        } catch {
            throw Self.mapError(error)
        }
    }

    private static func metadata(displayName: String?) -> [String: AnyJSON]? {
        guard let displayName else { return nil }
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return ["display_name": .string(trimmed)]
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
        default:
            return error
        }
    }
}
#endif
