import SwiftUI

@MainActor
protocol FocusInteractor: GlobalInteractor {
}

extension CoreInteractor: FocusInteractor { }
