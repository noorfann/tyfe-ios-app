import SwiftUI

@MainActor
protocol StreakInteractor: GlobalInteractor {
    var currentStreakData: CurrentStreakData { get }
    func getAllStreakEvents() async throws -> [StreakEvent]
}

extension CoreInteractor: StreakInteractor { }
