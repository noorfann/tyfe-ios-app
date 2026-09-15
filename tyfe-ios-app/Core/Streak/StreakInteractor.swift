import SwiftUI

@MainActor
protocol StreakInteractor: GlobalInteractor {
    var currentStreakData: CurrentStreakData { get }
}

extension CoreInteractor: StreakInteractor { }
