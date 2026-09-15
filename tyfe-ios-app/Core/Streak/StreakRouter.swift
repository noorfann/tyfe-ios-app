import SwiftUI

@MainActor
protocol StreakRouter: GlobalRouter { }

extension CoreRouter: StreakRouter { }
