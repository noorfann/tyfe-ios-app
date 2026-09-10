import SwiftUI

@MainActor
protocol SplashInteractor: GlobalInteractor {

}

extension CoreInteractor: SplashInteractor { }
