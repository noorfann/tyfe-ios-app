import SwiftUI

@MainActor
protocol FocusRouter: GlobalRouter { }

extension CoreRouter: FocusRouter { }
