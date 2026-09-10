import SwiftUI
import SwiftfulUI

struct SplashDelegate {
    var onFinished: () -> Void

    var eventParameters: [String: Any]? {
        nil
    }
}

struct SplashView: View {

    @State private var presenter: SplashPresenter
    let delegate: SplashDelegate

    init(presenter: SplashPresenter, delegate: SplashDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            VStack(spacing: TyfeSpacing.section) {
                wordmark
                motifRow
            }
        }
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
        .onChange(of: presenter.isFinished) { _, isFinished in
            if isFinished {
                delegate.onFinished()
            }
        }
    }

    private var wordmark: some View {
        VStack(spacing: TyfeSpacing.small) {
            Text("tyfe")
                .font(TyfeTypography.display)
                .tracking(-2.0)
                .foregroundStyle(TyfeEditorialPalette.ink)

            Text("Focus. Earn. Rest.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("tyfe. Focus, earn, rest.")
    }

    private var motifRow: some View {
        HStack(spacing: TyfeSpacing.small) {
            TyfeMotifView(kind: .tile)
            TyfeMotifView(kind: .badge)
            TyfeMotifView(kind: .completion)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Splash") {
    let container = DevPreview.shared.container()
    let interactor = CoreInteractor(container: container)

    return ZStack {
        TyfeEditorialPalette.canvas.ignoresSafeArea()
        SplashView(
            presenter: SplashPresenter(interactor: interactor),
            delegate: SplashDelegate(onFinished: {})
        )
    }
}

extension CoreBuilder {

    func splashView(onFinished: @escaping () -> Void) -> some View {
        SplashView(
            presenter: SplashPresenter(interactor: interactor),
            delegate: SplashDelegate(onFinished: onFinished)
        )
    }

}
