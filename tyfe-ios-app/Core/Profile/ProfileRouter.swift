import SwiftUI

@MainActor
protocol ProfileRouter: GlobalRouter { }

extension CoreRouter: ProfileRouter { }
