import SwiftUI

@MainActor
protocol StreakInteractor: GlobalInteractor {
    var currentStreakData: CurrentStreakData { get }
    var effortStreakDays: [EffortDayRecord] { get }
    func getAllStreakEvents() async throws -> [StreakEvent]
}

extension CoreInteractor: StreakInteractor { }

extension StreakInteractor {
    var effortStreakDays: [EffortDayRecord] { [] }
}

extension CoreInteractor {
    var effortStreakDays: [EffortDayRecord] { effortStreakManager.days }
}
