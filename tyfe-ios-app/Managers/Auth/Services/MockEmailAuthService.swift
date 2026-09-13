//
//  MockEmailAuthService.swift
//  tyfe-ios-app
//
//  Local-only email auth used by the Mock configuration, previews, and UI tests.
//  Never touches Supabase.
//

import Foundation
import SwiftfulAuthenticating

@MainActor
final class MockEmailAuthService: EmailAuthServicing {

    func register(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let trimmedName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let user = UserAuthInfo(
            uid: "mock_email_user",
            email: email,
            isAnonymous: false,
            authProviders: [.email],
            displayName: (trimmedName?.isEmpty == false) ? trimmedName : nil,
            creationDate: .now,
            lastSignInDate: .now
        )
        return (user, true)
    }

    func signIn(
        email: String,
        password: String
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool) {
        let user = UserAuthInfo(
            uid: "mock_email_user",
            email: email,
            isAnonymous: false,
            authProviders: [.email],
            displayName: nil,
            creationDate: .now,
            lastSignInDate: .now
        )
        return (user, false)
    }
}
