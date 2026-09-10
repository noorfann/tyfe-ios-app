import SwiftUI

@MainActor
protocol SplashRouter: GlobalRouter {

}

extension CoreRouter: SplashRouter { }
