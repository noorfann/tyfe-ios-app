//
//  SignUpRouter.swift
//  tyfe-ios-app
//

@MainActor
protocol SignUpRouter: GlobalRouter {
    func showSignInView(email: String, onDidSignIn: (() -> Void)?)
    func dismissScreen()
}

extension CoreRouter: SignUpRouter { }
