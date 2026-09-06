import SwiftUI

@MainActor
protocol StarterActivityInteractor: GlobalInteractor {
    var phase1Activities: [ActivityModel] { get }

    @discardableResult
    func createPhase1Activity(
        name: String,
        category: ActivityCategory?,
        colorToken: String?
    ) -> ActivityModel?
}

extension CoreInteractor: StarterActivityInteractor { }
