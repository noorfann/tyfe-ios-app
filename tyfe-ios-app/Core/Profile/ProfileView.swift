import PhotosUI
import SwiftUI
import SwiftfulUI

struct ProfileDelegate {
    var onDidSave: (() -> Void)?
}

struct ProfileView: View {
    @State private var presenter: ProfilePresenter

    init(presenter: ProfilePresenter) {
        _presenter = State(initialValue: presenter)
    }

    var body: some View {
        ZStack {
            TyfeEditorialPalette.canvas.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: TyfeSpacing.sectionGap) {
                    photoSection
                    identitySection
                    statusSection
                    TyfeActionButtonView(
                        title: presenter.isSaving ? "Saving…" : "Save",
                        systemImage: "checkmark", role: .primary,
                        onTap: { presenter.onSavePressed() }
                    )
                    .disabled(!presenter.canSave)
                    .accessibilityIdentifier("profile-save")
                }
                .padding(TyfeSpacing.screenInset)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { presenter.onCancelPressed() }
                    .disabled(presenter.isSaving)
                    .accessibilityIdentifier("profile-cancel")
            }
        }
        // Native pop gestures bypass draft confirmation. Every editor exit uses the presenter.
        .background(ProfileNavigationExitGuard())
        .interactiveDismissDisabled(true)
        .confirmationDialog("Discard your profile changes?", isPresented: Binding(
            get: { presenter.showsDiscardConfirmation },
            set: { if !$0 { presenter.onKeepEditingPressed() } }
        ), titleVisibility: .visible) {
            Button("Discard changes", role: .destructive) { presenter.onDiscardConfirmed() }
            Button("Keep editing", role: .cancel) { presenter.onKeepEditingPressed() }
        }
        .sheet(isPresented: Binding(
            get: { presenter.crop != nil },
            set: { if !$0 { presenter.onCancelCropPressed() } }
        )) {
            ProfileCropEditor(presenter: presenter)
                .interactiveDismissDisabled(true)
        }
        .onAppear { presenter.onViewAppear() }
        .onDisappear { presenter.onViewDisappear() }
        .onChange(of: presenter.isEditingAccount) { _, _ in presenter.onAccountStateChanged() }
        .task { await presenter.onFirstTask() }
    }

    private var photoSection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(spacing: TyfeSpacing.itemGap) {
                ProfileAvatarView(
                    initials: presenter.initials,
                    photoURL: presenter.currentPhotoURL,
                    draftImage: presenter.draftPhoto,
                    size: 112
                )
                PhotosPicker(selection: Binding(
                    get: { presenter.selectedPhoto },
                    set: { presenter.onPhotoSelected($0) }
                ), matching: .images, photoLibrary: .shared()) {
                    Label(presenter.hasPhoto ? "Replace photo" : "Choose photo", systemImage: "photo")
                        .font(TyfeTypography.interfaceStrong)
                        .frame(minHeight: 44)
                }
                .disabled(!presenter.canEditFields)
                .accessibilityIdentifier("profile-choose-photo")
                if presenter.hasPhoto {
                    Button("Remove photo", role: .destructive) { presenter.onRemovePhotoPressed() }
                        .frame(minHeight: 44)
                        .disabled(!presenter.canEditFields)
                }
                if presenter.isLoadingPhoto {
                    ProgressView("Opening photo…")
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var identitySection: some View {
        TyfeSurfaceView(role: .paper) {
            VStack(alignment: .leading, spacing: TyfeSpacing.itemGap) {
                Text("Name").font(TyfeTypography.interfaceStrong)
                TyfeTextFieldView(
                    placeholder: "Your name",
                    text: Binding(get: { presenter.name }, set: { presenter.onNameChanged($0) }),
                    autocapitalization: .words,
                    textContentType: .name,
                    submitLabel: .done
                )
                .disabled(!presenter.canEditFields)
                .accessibilityIdentifier("profile-name")
                if let message = presenter.nameValidationMessage {
                    Text(message)
                        .font(TyfeTypography.caption)
                        .foregroundStyle(TyfeEditorialPalette.muted)
                }
                Text("Email").font(TyfeTypography.interfaceStrong)
                Text(presenter.email ?? "No email available")
                    .font(TyfeTypography.interface)
                    .foregroundStyle(TyfeEditorialPalette.muted)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Your email is managed by your account and cannot be changed here.")
                    .font(TyfeTypography.caption)
                    .foregroundStyle(TyfeEditorialPalette.muted)
            }
        }
    }

    @ViewBuilder
    private var statusSection: some View {
        if presenter.isLoading {
            ProgressView("Loading profile…")
        }
        if let message = presenter.accountMessage {
            Text(message)
                .font(TyfeTypography.interface)
                .foregroundStyle(TyfeEditorialPalette.muted)
                .accessibilityIdentifier("profile-account-changed")
        }
        if let message = presenter.errorMessage {
            VStack(alignment: .leading, spacing: TyfeSpacing.relatedGap) {
                Text(message).font(TyfeTypography.interface)
                Button("Try again") { Task { await presenter.onRetryPressed() } }
                    .frame(minHeight: 44)
                    .disabled(!presenter.isEditingAccount || presenter.isLoading || presenter.isSaving || presenter.isLoadingPhoto)
            }
            .accessibilityIdentifier("profile-error")
        }
    }
}

extension CoreBuilder {
    func profileView(router: AnyRouter, delegate: ProfileDelegate = ProfileDelegate()) -> some View {
        ProfileView(presenter: ProfilePresenter(
            interactor: interactor,
            router: CoreRouter(router: router, builder: self),
            delegate: delegate
        ))
    }
}

extension CoreRouter {
    func showProfileView(delegate: ProfileDelegate) {
        router.showScreen(.push) { router in
            builder.profileView(router: router, delegate: delegate)
        }
    }
}
