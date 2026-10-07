import SwiftUI
import SwiftfulUI
import SwiftfulRouting

struct SignUpDelegate {
    var onDidSignIn: (() -> Void)?
    var onDidSignInToExistingAccount: (() -> Void)?
    var eventParameters: [String: Any]? { nil }
}

struct SignUpView: View {
    @State private var presenter: SignUpPresenter
    @FocusState private var focusedField: SignUpPresenter.Field?
    @Environment(\.scenePhase) private var scenePhase
    private let delegate: SignUpDelegate

    init(presenter: SignUpPresenter, delegate: SignUpDelegate) {
        _presenter = State(initialValue: presenter)
        self.delegate = delegate
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
                    header
                    progress
                    intro
                    credentialsForm
                    errorMessage
                    actions
                    if presenter.step != .complete { signInLink }
                    Text("Your activities and progress stay on this device.")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }
                .padding(.horizontal, TyfeSpacing.screenInset)
                .padding(.top, TyfeSpacing.screenInset)
                .padding(.bottom, TyfeSpacing.screenInset)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Text("Hide keyboard")
                    .asButton(.press) { focusedField = nil }
                Spacer()
                Text(presenter.primaryButtonTitle)
                    .asButton(.press) { submit() }
                    .disabled(!presenter.canSubmit)
            }
        }
        .interactiveDismissDisabled(presenter.isBusy)
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .task { await presenter.onFirstTask() }
        .task(id: scenePhase) {
            await presenter.updateResendCountdown(isActive: scenePhase == .active)
        }
        .onChange(of: focusedField) { oldValue, _ in presenter.onFieldEndedEditing(oldValue) }
        .onChange(of: presenter.step) { _, step in
            switch step {
            case .details: focusedField = .email
            case .verification: focusedField = presenter.isEmailVerified ? nil : .code
            case .password: focusedField = .password
            case .profile, .complete: focusedField = nil
            }
        }
        .onChange(of: presenter.isPasswordVisible) { _, _ in focusedField = .password }
    }

    private var header: some View {
        HStack(spacing: TyfeSpacing.relatedGap) {
            if presenter.canGoBack {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 44, height: 44)
                    .asButton(.press) { presenter.onBackPressed() }
                    .disabled(presenter.isBusy)
                    .accessibilityLabel("Back")
                    .accessibilityIdentifier("signup-back")
            }
            Text("CREATE YOUR ACCOUNT")
                .font(TyfeTypography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "xmark")
                .font(.headline.weight(.black))
                .foregroundStyle(TyfeEditorialPalette.ink)
                .frame(width: 44, height: 44)
                .asButton(.press) { presenter.onClosePressed() }
                .disabled(presenter.isBusy)
                .accessibilityLabel("Close")
                .accessibilityIdentifier("signup-close")
        }
    }

    @ViewBuilder
    private var progress: some View {
        if presenter.step != .complete {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                Text("Step \(presenter.stepNumber) of 3")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                ProgressView(value: Double(presenter.stepNumber), total: 3)
                    .tint(TyfeEditorialPalette.ink)
                    .accessibilityLabel("Account setup")
                    .accessibilityValue("Step \(presenter.stepNumber) of 3")
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            Text(introTitle)
                .font(TyfeTypography.display)
                .tracking(-1.6)
                .foregroundStyle(TyfeEditorialPalette.ink)
                .accessibilityIdentifier("signup-title")
            Text(introSubtitle)
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var introTitle: String {
        switch presenter.step {
        case .details: return "Make your\naccount yours."
        case .verification: return presenter.isEmailVerified ? "Email verified." : "Check your email."
        case .password: return "Choose your\npassword."
        case .profile: return "One last step."
        case .complete: return "Account ready"
        }
    }

    private var introSubtitle: String {
        switch presenter.step {
        case .details: return "Add your email so you can sign in to your account again."
        case .verification:
            return presenter.isEmailVerified
                ? "\(presenter.email) is verified. Continue to set your password."
                : "Enter the six-digit code sent to \(presenter.email). Can't find it? Check your spam folder."
        case .password: return "Your email is verified. Set a password to finish creating your account."
        case .profile: return "Your password is saved. Finish setting up your account on this device."
        case .complete: return "You can now sign in with \(presenter.email) and your password."
        }
    }

    @ViewBuilder
    private var credentialsForm: some View {
        if presenter.step == .details || presenter.step == .password
            || (presenter.step == .verification && !presenter.isEmailVerified) {
            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                    switch presenter.step {
                    case .details: detailsFields
                    case .verification: verificationField
                    case .password: passwordField
                    case .profile, .complete: EmptyView()
                    }
                }
            }
            .disabled(presenter.isBusy || presenter.isUnavailable)
        }
    }

    private var detailsFields: some View {
        Group {
            fieldLabel("DISPLAY NAME (OPTIONAL)")
            TyfeTextFieldView(
                placeholder: "Your name", text: fieldBinding(.displayName),
                autocapitalization: .words, textContentType: .name, submitLabel: .next
            )
            .focused($focusedField, equals: .displayName)
            .onSubmit { focusedField = .email }
            .accessibilityLabel("Display name, optional")
            .accessibilityIdentifier("signup-name")

            fieldLabel("EMAIL")
            TyfeTextFieldView(
                placeholder: "you@example.com", text: fieldBinding(.email),
                autocapitalization: .never, keyboardType: .emailAddress,
                textContentType: .emailAddress, submitLabel: .go
            )
            .focused($focusedField, equals: .email)
            .onSubmit { submit() }
            .accessibilityLabel("Email")
            .accessibilityIdentifier("signup-email")
            validationMessage(for: .email)
        }
    }

    private var verificationField: some View {
        Group {
            fieldLabel("VERIFICATION CODE")
            TyfeTextFieldView(
                placeholder: "Six-digit code", text: fieldBinding(.code),
                autocapitalization: .never, keyboardType: .numberPad,
                textContentType: .oneTimeCode, submitLabel: .done
            )
            .focused($focusedField, equals: .code)
            .onSubmit { submit() }
            .accessibilityLabel("Six-digit email verification code")
            .accessibilityIdentifier("signup-code")
            validationMessage(for: .code)
        }
    }

    private var passwordField: some View {
        Group {
            fieldLabel("PASSWORD")
            HStack(spacing: TyfeSpacing.relatedGap) {
                TyfeTextFieldView(
                    placeholder: "At least 6 characters", text: fieldBinding(.password),
                    autocapitalization: .never, isSecure: !presenter.isPasswordVisible,
                    textContentType: .newPassword, submitLabel: .go
                )
                .focused($focusedField, equals: .password)
                .onSubmit { submit() }
                .accessibilityLabel("New password")
                .accessibilityIdentifier("signup-password")
                Image(systemName: presenter.isPasswordVisible ? "eye.slash" : "eye")
                    .frame(width: 44, height: 44)
                    .asButton(.press) { presenter.onTogglePasswordPressed() }
                    .accessibilityLabel(presenter.isPasswordVisible ? "Hide password" : "Show password")
                    .accessibilityIdentifier("signup-password-visibility")
            }
            Text("Use at least 6 characters.")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
            validationMessage(for: .password)
        }
    }

    @ViewBuilder
    private func validationMessage(for field: SignUpPresenter.Field) -> some View {
        if let message = presenter.validationMessage(for: field) {
            Text(message)
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.errorFill)
                .accessibilityLabel("Error: \(message)")
        }
    }

    @ViewBuilder
    private var errorMessage: some View {
        if let message = presenter.errorMessage {
            Text(message)
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.errorFill)
                .accessibilityLabel("Error: \(message)")
                .accessibilityIdentifier("signup-error")
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            TyfeActionButtonView(
                title: presenter.primaryButtonTitle,
                systemImage: presenter.step == .complete ? "checkmark" : "arrow.right",
                isEnabled: presenter.canSubmit,
                onTap: { submit() }
            )
            .accessibilityIdentifier("signup-submit")

            if presenter.isBusy {
                ProgressView().tint(TyfeEditorialPalette.ink).frame(maxWidth: .infinity)
            }
            if presenter.resendSecondsRemaining > 0,
               presenter.step == .details || presenter.step == .verification {
                Text("You can request another code in \(presenter.resendSecondsRemaining)s.")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
            if presenter.step == .verification, !presenter.isEmailVerified {
                TyfeActionButtonView(
                    title: "Resend code", systemImage: "envelope", role: .secondary,
                    isEnabled: !presenter.isBusy && presenter.resendSecondsRemaining == 0,
                    onTap: { presenter.onResendPressed() }
                )
                .accessibilityIdentifier("signup-resend")
            }
        }
    }

    private var signInLink: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
            if !presenter.isEmailVerified {
                Text(presenter.offersSignIn ? "Sign in to your existing account" : "Already have an account? Sign in")
                    .font(TyfeTypography.interfaceStrong)
                    .foregroundStyle(TyfeEditorialPalette.ink)
                    .padding(.vertical, TyfeSpacing.relatedGap)
                    .asButton(.press) { presenter.onSignInPressed(delegate: delegate) }
                    .disabled(presenter.isBusy)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityIdentifier("signup-signin")
            }
            Text("You can close this screen and continue account setup later.")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private func submit() {
        focusedField = nil
        presenter.onSubmitPressed(delegate: delegate)
    }

    private func fieldBinding(_ field: SignUpPresenter.Field) -> Binding<String> {
        Binding(get: {
            switch field {
            case .displayName: presenter.displayName
            case .email: presenter.email
            case .code: presenter.code
            case .password: presenter.password
            }
        }, set: { presenter.onFieldValueChanged($0, for: field) })
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
            presenter: SignUpPresenter(interactor: interactor, router: CoreRouter(router: router, builder: self)),
            delegate: delegate
        )
    }
}

extension CoreRouter {
    func showSignUpView(delegate: SignUpDelegate = SignUpDelegate()) {
        showSignUpView(delegate: delegate, onDismiss: nil)
    }

    func showSignUpView(delegate: SignUpDelegate, onDismiss: (() -> Void)?) {
        let config = ResizableSheetConfig(detents: [.large], selection: nil, dragIndicator: .hidden)
        router.showScreen(.sheetConfig(config: config), onDismiss: onDismiss) { router in
            builder.signUpView(router: router, delegate: delegate)
        }
    }
}

#Preview {
    let dependencies = Dependencies(config: .mock(isSignedIn: false, addLogging: false))
    let container = dependencies.container
    let service = MockEmailAuthService(user: .mock(isAnonymous: true))
    container.register(EmailAuthServicing.self, service: service)
    container.register(AuthManager.self, service: AuthManager(service: service))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))
    return RouterView { router in
        builder.signUpView(router: router)
    }
}
