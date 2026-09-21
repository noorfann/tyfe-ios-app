import SwiftUI

@MainActor
protocol ModuleWrapperInteractor: GlobalInteractor {
    var activeFocusSession: FocusSessionModel? { get }
}

extension CoreInteractor: ModuleWrapperInteractor {
}
