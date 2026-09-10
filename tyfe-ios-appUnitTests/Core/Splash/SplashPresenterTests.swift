import Testing
@testable import tyfe_ios_app

@MainActor
struct SplashPresenterTests {

    private func makePresenter() -> SplashPresenter {
        let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
        let interactor = CoreInteractor(container: dependencies.container)
        return SplashPresenter(interactor: interactor, minimumDisplayDuration: 0.02)
    }

    @Test func splashIsNotFinishedUntilMinimumDisplayElapses() async {
        let presenter = makePresenter()

        #expect(!presenter.isFinished)

        presenter.onViewAppear(delegate: SplashDelegate(onFinished: {}))
        try? await Task.sleep(for: .milliseconds(80))

        #expect(presenter.isFinished)
    }

    @Test func splashDefaultMinimumDisplayIsBrief() {
        #expect(SplashPresenter.minDisplayDuration >= 0.5)
    }
}
