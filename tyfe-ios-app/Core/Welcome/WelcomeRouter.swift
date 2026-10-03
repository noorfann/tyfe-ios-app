import Foundation

@MainActor
protocol WelcomeRouter: GlobalRouter {
    func showSignUpView(delegate: SignUpDelegate, onDismiss: (() -> Void)?)
    func showSignInSheet(onDidSignIn: (() -> Void)?, onDismiss: (() -> Void)?)
}

extension CoreRouter: WelcomeRouter { }
