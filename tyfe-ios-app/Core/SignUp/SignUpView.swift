//
//  SignUpView.swift
//  tyfe-ios-app
//

import SwiftUI
import SwiftfulUI
import SwiftfulRouting

struct SignUpDelegate {
    var onDidSignIn: (() -> Void)?

    init(onDidSignIn: (() -> Void)? = nil) {
        self.onDidSignIn = onDidSignIn
    }

    var eventParameters: [String: Any]? { nil }
}

struct SignUpView: View {

    @State private var presenter: SignUpPresenter
    private let delegate: SignUpDelegate

    init(presenter: SignUpPresenter, delegate: SignUpDelegate) {
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
                    signInLink
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
            Text("SAVE YOUR PROGRESS")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) {
                    presenter.onClosePressed()
                }
                .accessibilityLabel("Close")
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Keep your progress\non every device.")
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)

            Text("Create an email and password so your account is yours to keep.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var credentialsForm: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                fieldLabel("DISPLAY NAME")
                TyfeTextFieldView(placeholder: "Your name", text: $presenter.displayName)

                fieldLabel("EMAIL")
                TyfeTextFieldView(
                    placeholder: "you@example.com",
                    text: $presenter.email,
                    autocapitalization: .never
                )

                fieldLabel("PASSWORD")
                TyfeTextFieldView(
                    placeholder: "At least 6 characters",
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
                title: presenter.isSubmitting ? "Creating account…" : "Create account",
                systemImage: "envelope.badge",
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

    private var signInLink: some View {
        HStack(spacing: TyfeSpacing.small) {
            Text("Already have an account?")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)

            Text("Sign in")
                .font(TyfeTypography.interfaceStrong)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .asButton(.press) {
                    presenter.onSignInPressed(delegate: delegate)
                }
                .accessibilityAddTraits(.isButton)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(TyfeTypography.eyebrow)
            .tracking(1.2)
            .foregroundStyle(TyfeEditorialPalette.muted)
    }
}

extension CoreBuilder {
    func signUpView(router: AnyRouter, delegate: SignUpDelegate = SignUpDelegate()) -> some View {
        SignUpView(
            presenter: SignUpPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            ),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showSignUpView(delegate: SignUpDelegate = SignUpDelegate()) {
        let config = ResizableSheetConfig(
            detents: [.medium, .large],
            selection: nil,
            dragIndicator: .hidden
        )

        router.showScreen(.sheetConfig(config: config)) { router in
            builder.signUpView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let container = DevPreview.shared.container()
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.signUpView(router: router)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }
}
