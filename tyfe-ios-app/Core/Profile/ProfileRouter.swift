import SwiftUI

@MainActor
protocol ProfileRouter: GlobalRouter {
    func dismissScreen()
}

extension CoreRouter: ProfileRouter { }
