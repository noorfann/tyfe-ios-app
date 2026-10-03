import SwiftUI
import SwiftfulUI

struct SettingsView: View {
    @State private var presenter: SettingsPresenter

    init(presenter: SettingsPresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.section) {
                    Text("Settings")
                        .font(TyfeTypography.display)
                        .tracking(-1.6)
                    profileSection
                    appearanceSection
                    purchasesSection
                    applicationSection
                }
                .padding(.horizontal, TyfeSpacing.control)
                .padding(.top, TyfeSpacing.control)
                .padding(.bottom, TyfeSpacing.section)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
    }

    private var profileSection: some View {
        section("Profile") {
            VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                HStack(alignment: .top, spacing: TyfeSpacing.control) {
                    ProfileAvatarView(initials: presenter.initials, photoURL: presenter.photoURL)
                    VStack(alignment: .leading, spacing: TyfeSpacing.small) {
                        Text(presenter.displayName)
                            .font(TyfeTypography.interfaceStrong)
                            .fixedSize(horizontal: false, vertical: true)
                        if let email = presenter.email {
                            Text(email)
                                .font(TyfeTypography.caption)
                                .foregroundStyle(TyfeEditorialPalette.muted)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if presenter.needsAccountSetup {
                            Text(presenter.accountTitle)
                                .font(TyfeTypography.caption)
                                .foregroundStyle(TyfeEditorialPalette.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                TyfeActionButtonView(
                    title: presenter.accountActionTitle,
                    systemImage: presenter.canEditProfile ? "pencil" : "person.crop.circle.badge.plus",
                    role: .secondary,
                    onTap: { presenter.onProfilePressed() }
                )
                .accessibilityIdentifier(presenter.canEditProfile ? "settings-edit-profile" : "settings-create-account")
            }
        }
    }

    private var appearanceSection: some View {
        section("Appearance") {
            Toggle("Dark mode", isOn: Binding(
                get: { presenter.isDarkMode },
                set: { presenter.onDarkModeChanged($0) }
            ))
            .font(TyfeTypography.interface)
            .tint(TyfeEditorialPalette.ink)
            .accessibilityIdentifier("settings-dark-mode")
        }
    }

    private var purchasesSection: some View {
        section("Purchases") {
            Text("There are no in-app purchases available at this time.")
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var applicationSection: some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.control) {
            section("Application") {
                VStack(alignment: .leading, spacing: TyfeSpacing.control) {
                    detailRow(title: "Version", value: Utilities.appVersion ?? "—")
                    detailRow(title: "Build number", value: Utilities.buildNumber ?? "—")
                    TyfeActionButtonView(
                        title: "Contact us", systemImage: "envelope", role: .secondary,
                        onTap: { presenter.onContactUsPressed() }
                    )
                    if presenter.isSignedIn {
                        TyfeActionButtonView(
                            title: "Sign out", systemImage: "rectangle.portrait.and.arrow.right", role: .secondary,
                            onTap: { presenter.onSignOutPressed() }
                        )
                        TyfeActionButtonView(
                            title: "Delete account", systemImage: "trash", role: .destructive,
                            onTap: { presenter.onDeleteAccountPressed() }
                        )
                    }
                }
            }
            Text("2026 Zulfikar Noorfan ©")
                .font(TyfeTypography.caption)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: TyfeSpacing.small) {
            Text(title).font(TyfeTypography.interfaceStrong)
            TyfeSurfaceView(role: .paper, content: content)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: TyfeSpacing.small) {
            Text(title)
            Spacer()
            Text(value).foregroundStyle(TyfeEditorialPalette.muted)
        }
        .font(TyfeTypography.interface)
    }
}

extension CoreBuilder {
    func settingsView(router: AnyRouter) -> some View {
        SettingsView(presenter: SettingsPresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self)
        ))
    }
}
