//
//  SignInView.swift
//  tyfe-ios-app
//

import SwiftUI
import SwiftfulUI
import SwiftfulRouting

struct SignInDelegate {
    var onDidSignIn: (() -> Void)?

    init(onDidSignIn: (() -> Void)? = nil) {
        self.onDidSignIn = onDidSignIn
    }

    var eventParameters: [String: Any]? { nil }
}

struct SignInView: View {

    @State private var presenter: SignInPresenter
    private let delegate: SignInDelegate

    init(presenter: SignInPresenter, delegate: SignInDelegate) {
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
                    intro
                    credentialsForm
                    errorMessage
                    actions
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            presenter.onViewAppear()
        }
        .onDisappear {
            presenter.onViewDisappear()
        }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.small) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    presenter.onBackPressed()
                }
                .accessibilityLabel("Back")

            Text("SIGN IN")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Welcome back.")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)

            Text("Sign in with the email and password you used to save your account.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var credentialsForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                fieldLabel("EMAIL")
                TyfeTextFieldView(
                    placeholder: "you@example.com",
                    text: $presenter.email,
                    autocapitalization: .never
                )

                fieldLabel("PASSWORD")
                TyfeTextFieldView(
                    placeholder: "Your password",
                    text: $presenter.password,
                    autocapitalization: .never,
                    isSecure: true
                )
            }
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let message = presenter.errorMessage {
            Text(message)
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.errorFill)
                .accessibilityLabel(Text("Error: \(message)"))
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            TyfeActionButtonView(
                title: presenter.isSubmitting ? "Signing in…" : "Sign in",
                systemImage: "arrow.right",
                isEnabled: presenter.canSubmit,
                onTap: { presenter.onSubmitPressed(delegate: delegate) }
            )

            if presenter.isSubmitting {
                ProgressView()
                    .tint(TyfeEditorialPalette.ink)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(TyfeTypography.eyebrow)
            .tracking(1.2)
            .foregroundStyle(TyfeEditorialPalette.muted)
    }
}

extension CoreBuilder {
    func signInView(router: AnyRouter, delegate: SignInDelegate = SignInDelegate()) -> some View {
        SignInView(
            presenter: SignInPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showSignInView(onDidSignIn: (() -> Void)?) {
        router.showScreen(.push) { router in
            builder.signInView(router: router, delegate: SignInDelegate(onDidSignIn: onDidSignIn))
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.signInView(router: router)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
