import SwiftUI

@MainActor
protocol ModuleWrapperRouter: GlobalRouter {

}

extension CoreRouter: ModuleWrapperRouter { }
