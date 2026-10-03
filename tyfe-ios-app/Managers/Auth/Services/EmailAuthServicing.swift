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
    var authenticatedUser: UserAuthInfo? { get }
    var pendingRegistration: PendingEmailRegistration? { get }

    func restoreRegistration() async throws -> PendingEmailRegistration?
    func beginRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration
    func verifyRegistrationCode(_ code: String) async throws -> PendingEmailRegistration
    func resendRegistrationCode() async throws -> PendingEmailRegistration
    func finishRegistration(password: String) async throws -> UserAuthInfo
    func acknowledgeRegistrationComplete() throws
    func resetRegistrationAfterSignOut() throws

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
    case invalidEmail
    case invalidCode
    case sessionChanged
    case alreadySignedIn
    case invalidStage

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
        case .invalidEmail:
            return "Enter a valid email address."
        case .invalidCode:
            return "That code is invalid or expired. Try again or request a new code."
        case .sessionChanged:
            return "Your account session changed. Reopen account setup to continue safely."
        case .alreadySignedIn:
            return "You're already signed in to an account."
        case .invalidStage:
            return "Reopen account setup to continue from your last step."
        }
    }
}
