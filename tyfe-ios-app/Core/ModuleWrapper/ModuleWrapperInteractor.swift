import SwiftUI

@MainActor
protocol ModuleWrapperInteractor: GlobalInteractor {

}

extension CoreInteractor: ModuleWrapperInteractor { }
