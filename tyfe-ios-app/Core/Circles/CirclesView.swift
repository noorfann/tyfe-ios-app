import SwiftUI
import SwiftfulUI

struct CirclesDelegate {
    var eventParameters: [String: Any]? { nil }
}

struct CirclesView: View {

    @State private var presenter: CirclesPresenter
    let delegate: CirclesDelegate

    init(presenter: CirclesPresenter, delegate: CirclesDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    placeholderCard
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear(delegate: delegate)
        }
        .onDisappear {
            presenter.onViewDisappear(delegate: delegate)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Circles")
                .font(TyfeTypography.display)
                .tracking(-1.6)

            Text("Private accountability, when you want it.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var placeholderCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                TyfeMotifView(kind: .tile)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .accessibilityHidden(true)

                Label("Circles are coming soon", systemImage: "person.3.fill")
                    .font(TyfeTypography.displayCompact)

                Text("Soon you'll be able to share limited progress with a private Circle and cheer each other on. Nothing here is shared until you choose it.")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Circles are coming soon")
    }
}

#Preview("Circles") {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.circlesView(router: router, delegate: CirclesDelegate())
    }
}

extension CoreBuilder {

    func circlesView(router: AnyRouter, delegate: CirclesDelegate) -> some View {
        CirclesView(
            presenter: CirclesPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {

    func showCirclesView(delegate: CirclesDelegate = CirclesDelegate()) {
        router.showScreen(.push) { router in
            builder.circlesView(router: router, delegate: delegate)
        }
    }
}
