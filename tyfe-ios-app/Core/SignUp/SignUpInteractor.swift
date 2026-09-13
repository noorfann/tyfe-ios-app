//
//  SignUpInteractor.swift
//  tyfe-ios-app
//

@MainActor
protocol SignUpInteractor: GlobalInteractor {
    var suggestedDisplayName: String? { get }

    func registerWithEmail(
        email: String,
        password: String,
        displayName: String?
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool)

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
}

extension CoreInteractor: SignUpInteractor { }
