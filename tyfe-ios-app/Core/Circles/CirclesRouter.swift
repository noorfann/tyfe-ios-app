import SwiftUI

@MainActor
protocol CirclesRouter: GlobalRouter { }

extension CoreRouter: CirclesRouter { }
