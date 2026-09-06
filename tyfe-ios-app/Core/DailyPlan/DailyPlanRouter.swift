import SwiftUI

@MainActor
protocol DailyPlanRouter: GlobalRouter { }

extension CoreRouter: DailyPlanRouter { }
