import PhotosUI
import SwiftUI

@Observable
@MainActor
final class ProfilePresenter {
    private let interactor: ProfileInteractor
    private let router: ProfileRouter
    private let delegate: ProfileDelegate
    private let editingUserId: String?
    private let editingSignInDate: Date?
    private let editingSessionGeneration: Int
    private var originalName = ""
    private var originalHasPhoto = false
    private var didLoad = false
    private var isSessionInvalidated = false

    private(set) var name = ""
    private(set) var email: String?
    private(set) var photoChange: ProfilePhotoChange = .unchanged
    private(set) var draftPhoto: UIImage?
    private(set) var crop: ProfilePhotoCrop?
    private(set) var isLoading = true
    private(set) var isSaving = false
    private(set) var isLoadingPhoto = false
    private(set) var errorMessage: String?
    private(set) var failedOperation: FailedOperation?
    private(set) var showsDiscardConfirmation = false
    private(set) var selectedPhoto: PhotosPickerItem?

    @ObservationIgnored private(set) var saveTask: Task<Void, Never>?
    @ObservationIgnored private(set) var photoTask: Task<Void, Never>?

    enum FailedOperation { case refresh, save, photo, crop }

    init(interactor: ProfileInteractor, router: ProfileRouter, delegate: ProfileDelegate = ProfileDelegate()) {
        self.interactor = interactor
        self.router = router
        self.delegate = delegate
        self.editingUserId = interactor.currentAuthUserId
        self.editingSignInDate = interactor.auth?.lastSignInDate
        self.editingSessionGeneration = interactor.profileSessionGeneration
        seedFromIdentity()
    }

    var isEditingAccount: Bool {
        !isSessionInvalidated && editingUserId != nil && interactor.canEditProfile
            && interactor.auth?.uid == editingUserId
            && interactor.auth?.isAnonymous == false
            && interactor.pendingEmailRegistration == nil
            && interactor.currentAuthUserId == editingUserId
            && interactor.auth?.lastSignInDate == editingSignInDate
            && interactor.profileSessionGeneration == editingSessionGeneration
    }

    var initials: String { ProfileDisplayIdentity.initials(name: name) }
    var currentPhotoURL: URL? {
        guard isEditingAccount, photoChange == .unchanged else { return nil }
        return interactor.profilePhotoURL
    }
    var hasPhoto: Bool { draftPhoto != nil || (photoChange == .unchanged && originalHasPhoto) }
    var hasChanges: Bool { ProfileValidation.trimmedName(name) != originalName || photoChange != .unchanged }
    var hasUnsavedDraft: Bool { name != originalName || photoChange != .unchanged || crop != nil || selectedPhoto != nil }
    var canEditFields: Bool { isEditingAccount && !isLoading && !isSaving && !isLoadingPhoto && crop == nil }
    var canSave: Bool { canEditFields && hasChanges && ProfileValidation.isValidName(name) }
    var nameValidationMessage: String? {
        ProfileValidation.isValidName(name) ? nil : "Enter a name between 1 and 60 characters."
    }
    var accountMessage: String? {
        isEditingAccount ? nil : "Your account has changed or account setup is unfinished. Cancel and reopen your profile after signing in."
    }

    func onViewAppear() {
        interactor.trackScreenEvent(event: Event.appear)
    }

    func onViewDisappear() {
        interactor.trackEvent(event: Event.disappear)
        photoTask?.cancel()
    }

    func onFirstTask() async {
        guard !didLoad else { return }
        didLoad = true
        await refreshIdentity()
    }

    func refreshIdentity() async {
        guard ensureEditingAccount(), !isSaving, !isLoadingPhoto, crop == nil else {
            isLoading = false
            return
        }
        let preserveDraft = hasUnsavedDraft
        isLoading = true
        clearError()
        defer { isLoading = false }
        do {
            try await interactor.refreshProfile()
            guard ensureEditingAccount(), !Task.isCancelled else { return }
            if !preserveDraft { seedFromIdentity() }
        } catch {
            guard ensureEditingAccount(), !Task.isCancelled else { return }
            showError(error, operation: .refresh)
        }
    }

    func onNameChanged(_ value: String) {
        guard ensureEditingAccount(), canEditFields else { return }
        name = value
    }

    func onPhotoSelected(_ item: PhotosPickerItem?) {
        guard ensureEditingAccount(), canEditFields, let item else { return }
        selectedPhoto = item
        loadSelectedPhoto()
    }

    private func loadSelectedPhoto() {
        guard ensureEditingAccount(), !isSaving, !isLoading, let selectedPhoto else { return }
        photoTask?.cancel()
        isLoadingPhoto = true
        clearError()
        photoTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isLoadingPhoto = false }
            do {
                guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else {
                    throw ProfilePhotoError.unreadableImage
                }
                guard self.ensureEditingAccount(), !Task.isCancelled else { return }
                try self.onPhotoDataLoaded(data)
            } catch {
                guard self.ensureEditingAccount(), !Task.isCancelled else { return }
                self.showError(error, operation: .photo)
            }
        }
    }

    /// The library's original bytes are decoded only for cropping; they are never uploaded.
    func onPhotoDataLoaded(_ data: Data) throws {
        guard ensureEditingAccount(), !isSaving, !isLoading else { throw ProfileServiceError.accountChanged }
        crop = ProfilePhotoCrop(image: try ProfilePhotoProcessor.decode(data))
    }

    func onCropChanged(zoom: CGFloat, offset: CGSize) {
        guard ensureEditingAccount(), !isSaving, var crop else { return }
        crop.transform.update(zoom: zoom, offset: offset, imageSize: crop.image.size)
        self.crop = crop
    }

    func onUsePhotoPressed() {
        guard ensureEditingAccount(), !isSaving, let crop else { return }
        do {
            let exported = try ProfilePhotoProcessor.export(crop)
            photoChange = .replace(exported.jpeg)
            draftPhoto = exported.image
            self.crop = nil
            selectedPhoto = nil
            clearError()
        } catch {
            showError(error, operation: .crop)
        }
    }

    func onCancelCropPressed() {
        crop = nil
        selectedPhoto = nil
        clearError()
    }

    func onRemovePhotoPressed() {
        guard ensureEditingAccount(), canEditFields, hasPhoto else { return }
        draftPhoto = nil
        photoChange = originalHasPhoto ? .remove : .unchanged
        selectedPhoto = nil
        clearError()
    }

    func onSavePressed() {
        guard ensureEditingAccount() else { return }
        guard canSave else { return }
        let savedName = ProfileValidation.trimmedName(name)
        let savedPhoto = photoChange
        isSaving = true
        clearError()
        interactor.trackEvent(event: Event.saveStart)
        saveTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isSaving = false }
            do {
                guard self.ensureEditingAccount() else { return }
                try await self.interactor.saveProfile(name: savedName, photo: savedPhoto)
                guard self.ensureEditingAccount(), !Task.isCancelled else { return }
                self.originalName = savedName
                self.name = savedName
                self.photoChange = .unchanged
                self.draftPhoto = nil
                self.interactor.trackEvent(event: Event.saveSuccess)
                self.delegate.onDidSave?()
                self.router.dismissScreen()
            } catch {
                guard self.ensureEditingAccount(), !Task.isCancelled else { return }
                self.showError(error, operation: .save)
                self.interactor.trackEvent(event: Event.saveFailure)
            }
        }
    }

    func onRetryPressed() async {
        guard ensureEditingAccount(), !isSaving else { return }
        switch failedOperation {
        case .refresh: await refreshIdentity()
        case .save: onSavePressed()
        case .photo: loadSelectedPhoto()
        case .crop: onUsePhotoPressed()
        case nil: break
        }
    }

    func onCancelPressed() {
        guard !isSaving else { return }
        if hasUnsavedDraft {
            showsDiscardConfirmation = true
        } else {
            dismissEditor()
        }
    }

    func onKeepEditingPressed() { showsDiscardConfirmation = false }

    func onDiscardConfirmed() {
        guard !isSaving, hasUnsavedDraft else { return }
        showsDiscardConfirmation = false
        dismissEditor()
    }

    func onAccountStateChanged() {
        guard !isEditingAccount else { return }
        isSessionInvalidated = true
        photoTask?.cancel()
        saveTask?.cancel()
        originalName = ""
        originalHasPhoto = false
        name = ""
        email = nil
        photoChange = .unchanged
        draftPhoto = nil
        crop = nil
        selectedPhoto = nil
        isLoading = false
        isSaving = false
        isLoadingPhoto = false
        showsDiscardConfirmation = false
        clearError()
    }

    private func ensureEditingAccount() -> Bool {
        guard isEditingAccount else {
            onAccountStateChanged()
            return false
        }
        return true
    }

    private func dismissEditor() {
        photoTask?.cancel()
        router.dismissScreen()
    }

    private func seedFromIdentity() {
        let user = interactor.currentUser?.userId == editingUserId ? interactor.currentUser : nil
        originalName = ProfileDisplayIdentity.name(user: user, auth: interactor.auth) ?? ""
        name = originalName
        email = interactor.auth?.email ?? user?.emailCalculated
        originalHasPhoto = user?.avatarPath != nil || interactor.profilePhotoURL != nil
    }

    private func clearError() {
        errorMessage = nil
        failedOperation = nil
    }

    private func showError(_ error: Error, operation: FailedOperation) {
        errorMessage = error.localizedDescription
        failedOperation = operation
    }
}

extension ProfilePresenter {
    enum Event: String, LoggableEvent {
        case appear = "ProfileView_Appear"
        case disappear = "ProfileView_Disappear"
        case saveStart = "ProfileView_Save_Start"
        case saveSuccess = "ProfileView_Save_Success"
        case saveFailure = "ProfileView_Save_Fail"
        var eventName: String { rawValue }
        var parameters: [String: Any]? { nil }
        var type: LogType { self == .saveFailure ? .severe : .analytic }
    }
}
