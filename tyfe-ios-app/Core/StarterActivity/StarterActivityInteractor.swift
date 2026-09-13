import SwiftUI

@MainActor
protocol StarterActivityInteractor: GlobalInteractor {
    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel?
}

extension CoreInteractor: StarterActivityInteractor { }
