import SwiftUI

@MainActor
protocol CirclesRouter: GlobalRouter {
    func showSignUpView(delegate: SignUpDelegate)
    func showCirclesSignInView(onDidSignIn: (() -> Void)?)
}

extension CoreRouter: CirclesRouter { }
