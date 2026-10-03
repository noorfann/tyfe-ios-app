//
//  SignUpInteractor.swift
//  tyfe-ios-app
//

@MainActor
protocol SignUpInteractor: GlobalInteractor {
    var suggestedDisplayName: String? { get }
    var pendingEmailRegistration: PendingEmailRegistration? { get }

    func restoreEmailRegistration() async throws -> PendingEmailRegistration?
    func beginEmailRegistration(email: String, displayName: String?) async throws -> PendingEmailRegistration
    func verifyEmailRegistrationCode(_ code: String) async throws -> PendingEmailRegistration
    func resendEmailRegistrationCode() async throws -> PendingEmailRegistration
    func finishEmailRegistration(password: String) async throws
}

extension CoreInteractor: SignUpInteractor { }
