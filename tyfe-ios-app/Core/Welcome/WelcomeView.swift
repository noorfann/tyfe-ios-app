import SwiftUI
import SwiftfulRouting

struct WelcomeView: View {
    @State private var presenter: WelcomePresenter

    init(presenter: WelcomePresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                introduction
                choices
                if let error = presenter.errorMessage {
                    Text(error)
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.errorFill)
                        .accessibilityLabel("Error: \(error)")
                        .accessibilityIdentifier("welcome-error")
                }
            }
            .padding(.horizontal, TyfeSpacing.control)
            .padding(.vertical, TyfeSpacing.section)
        }
        .scrollIndicators(.hidden)
        .background(TyfeEditorialPalette.canvas.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { presenter.onViewAppear() }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            TyfeMotifView(kind: .completion)
                .accessibilityHidden(true)
            Text("WELCOME TO TYFE")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
            Text("Welcome to Tyfe")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityHeading(.h1)
            Text("Use Today and Rewards as a guest. An account is required for Circles. Activities and progress stay on this device.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var choices: some View {
        VStack(spacing: TyfeSpacing.control) {
            TyfeActionButtonView(
                title: presenter.accountActionTitle,
                systemImage: "person.crop.circle.badge.plus",
                isEnabled: !presenter.isPreparingSignup && !presenter.isAuthPresented,
                onTap: { presenter.onCreateAccountPressed() }
            )
            .accessibilityIdentifier("welcome-create-account")
            TyfeActionButtonView(
                title: "Sign in", systemImage: "arrow.right", role: .secondary,
                isEnabled: !presenter.isPreparingSignup && !presenter.isAuthPresented,
                onTap: { presenter.onSignInPressed() }
            )
            .accessibilityIdentifier("welcome-sign-in")
            TyfeActionButtonView(
                title: "Continue as guest", role: .secondary,
                isEnabled: !presenter.isAuthPresented,
                onTap: { presenter.onContinueAsGuestPressed() }
            )
            .accessibilityIdentifier("welcome-continue-guest")
            if presenter.isPreparingSignup {
                ProgressView("Preparing account…")
                    .tint(TyfeEditorialPalette.ink)
            }
        }
    }
}

extension CoreBuilder {
    func welcomeView(router: AnyRouter) -> some View {
        WelcomeView(presenter: WelcomePresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)))
    }
}

#Preview("Welcome") {
    let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
    let builder = CoreBuilder(interactor: CoreInteractor(container: dependencies.container))
    return RouterView { router in builder.welcomeView(router: router) }
}
