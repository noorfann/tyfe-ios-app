import SwiftUI
import Testing
@testable import tyfe_ios_app

@MainActor
struct StreakPresenterTests {
    @Test func freezeGuidanceExplainsEarningCapAndAutomaticUse() {
        let dependencies = Dependencies(config: .mock(isSignedIn: true, addLogging: false))
        let presenter = StreakPresenter(
            interactor: CoreInteractor(container: dependencies.container),
            router: StreakRouterTestDouble()
        )

        #expect(presenter.freezeGuidance == StreakFreezePolicy.guidance)
    }
}

@MainActor
private final class StreakRouterTestDouble: StreakRouter {
    var router: AnyRouter { fatalError("Router storage is unused by this test double") }
}
