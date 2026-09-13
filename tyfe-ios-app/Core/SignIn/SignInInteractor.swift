//
//  SignInInteractor.swift
//  tyfe-ios-app
//

@MainActor
protocol SignInInteractor: GlobalInteractor {
    func signInWithEmail(
        email: String,
        password: String
    ) async throws -> (user: UserAuthInfo, isNewUser: Bool)

    func logIn(user: UserAuthInfo, isNewUser: Bool) async throws
}

extension CoreInteractor: SignInInteractor { }
