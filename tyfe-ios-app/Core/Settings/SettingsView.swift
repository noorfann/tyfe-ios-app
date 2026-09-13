import SwiftUI
import SwiftfulUI

struct SettingsView: View {

    @State private var presenter: SettingsPresenter

    init(presenter: SettingsPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    header
                    accountCard
                    purchaseSection
                    applicationSection
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
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text("Settings")
                .font(TyfeTypography.display)
                .tracking(-1.6)

            Text("Your account, sharing, and app details.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

    private var accountCard: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                Text(presenter.accountTitle)
                    .font(TyfeTypography.interfaceStrong)

                if presenter.isSignedIn {
                    Text("Cheers today: \(presenter.cheersToday)")
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                        .accessibilityLabel(Text("Cheers today, \(presenter.cheersToday)"))

                    Text("Your Circles sync quietly in the background.")
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    if presenter.isAnonymousUser {
                        TyfeActionButtonView(
                            title: "Save & back up account",
                            systemImage: "person.crop.circle.badge.plus",
                            role: .primary,
                            onTap: { presenter.onCreateAccountPressed() }
                        )
                    } else {
                        TyfeActionButtonView(
                            title: "Sign out",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            role: .secondary,
                            onTap: { presenter.onSignOutPressed() }
                        )
                    }
                } else {
                    Text("Turn on Circles to share today's progress with your private groups.")
                        .font(TyfeTypography.interface)
                        .foregroundStyle(TyfeEditorialPalette.muted)

                    TyfeActionButtonView(
                        title: "Save & back up account",
                        systemImage: "person.crop.circle.badge.plus",
                        role: .primary,
                        onTap: { presenter.onCreateAccountPressed() }
                    )
                }
            }
        }
    }

    private var purchaseSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            Text("Purchases")
                .font(TyfeTypography.interfaceStrong)

            TyfeSurfaceView(role: .paper) {
                HStack(spacing: TyfeSpacing.small) {
                    Text("Account status")
                        .font(TyfeTypography.interface)
                    Spacer()
                    TyfePillView(
                        label: presenter.isPremium ? "Premium" : "Free",
                        systemImage: presenter.isPremium ? "star.fill" : "star",
                        tone: presenter.isPremium ? .warning : .neutral
                    )
                }
            }
        }
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            Text("Application")
                .font(TyfeTypography.interfaceStrong)

            TyfeSurfaceView(role: .paper) {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    detailRow(title: "Version", value: Utilities.appVersion ?? "—")
                    detailRow(title: "Build Number", value: Utilities.buildNumber ?? "—")

                    TyfeActionButtonView(
                        title: "Contact us",
                        systemImage: "envelope.fill",
                        role: .secondary,
                        onTap: { presenter.onContactUsPressed() }
                    )
                }
            }

            if presenter.isSignedIn {
                TyfeActionButtonView(
                    title: "Delete account",
                    systemImage: "trash",
                    role: .destructive,
                    onTap: { presenter.onDeleteAccountPressed() }
                )
            }

            Text("2026 Zulfikar Noorfan ©️")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(spacing: TyfeSpacing.small) {
            Text(title)
                .font(TyfeTypography.interface)
            Spacer()
            Text(value)
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
        }
    }

}

#Preview("No auth") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: nil)))
    container.register(UserManager.self, service: UserManager.mock())
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.settingsView(router: router)
    }
}
#Preview("Anonymous") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: true))))
    container.register(UserManager.self, service: UserManager.mock(user: .mock))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.settingsView(router: router)
    }
}
#Preview("Not anonymous") {
    let container = DevPreview.shared.container()
    container.register(AuthManager.self, service: AuthManager(service: MockAuthService(user: UserAuthInfo.mock(isAnonymous: false))))
    container.register(UserManager.self, service: UserManager.mock(user: .mock))
    let builder = CoreBuilder(interactor: CoreInteractor(container: container))

    return RouterView { router in
        builder.settingsView(router: router)
    }
}

extension CoreBuilder {

    func settingsView(router: AnyRouter) -> some View {
        SettingsView(
            presenter: SettingsPresenter(
                interactor: interactor,
                router: CoreRouter(router: router, builder: self)
            )
        )
    }

}
