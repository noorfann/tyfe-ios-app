//
//  SignUpRouter.swift
//  tyfe-ios-app
//

@MainActor
protocol SignUpRouter: GlobalRouter {
    func showSignInView(onDidSignIn: (() -> Void)?)
}

extension CoreRouter: SignUpRouter { }
