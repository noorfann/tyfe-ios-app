//
//  EmailAuthServicing.swift
//  tyfe-ios-app
//
//  App-owned email + password auth seam. SwiftfulAuthenticating's `AuthService`
//  does not model email/password, so this service bypasses that abstraction and
//  feeds the resulting user into the existing login flow.
//

import Foundation
import SwiftfulAuthenticating

@MainActor
protocol EmailAuthServicing: AnyObject {
    func register(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool)

    func signIn(
        email: String,
        password: String
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool)
}

enum EmailAuthError: LocalizedError, Equatable {
    case confirmationRequired
    case invalidCredentials
    case emailAlreadyInUse
    case weakPassword
    case rateLimited
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .confirmationRequired:
            return "Check your email to confirm your account, then sign in."
        case .invalidCredentials:
            return "That email and password combination doesn't match an account."
        case .emailAlreadyInUse:
            return "An account already exists for that email. Try signing in instead."
        case .weakPassword:
            return "Choose a stronger password with at least 6 characters."
        case .rateLimited:
            return "Too many attempts. Wait a moment and try again."
        case .notConfigured:
            return "Account creation isn't available right now."
        }
    }
}
