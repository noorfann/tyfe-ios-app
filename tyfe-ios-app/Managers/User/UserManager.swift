//
//  UserManager2.swift
//  tyfe-ios-app
//
//  Created by Nick Sarno on 1/17/25.
//

import SwiftUI
import SwiftfulDataManagers

@MainActor
@Observable
class UserManager {

    private let userSyncEngine: DocumentSyncEngine<UserModel>
    private var logger: (any DataSyncLogger)? { userSyncEngine.logger }

    var currentUser: UserModel? {
        userSyncEngine.currentDocument
    }

    init(userSyncEngine: DocumentSyncEngine<UserModel>) {
        self.userSyncEngine = userSyncEngine

        // Add user properties to analytics if user is cached
        if let user = currentUser, let logger {
            logger.trackEvent(event: Event.userPropertiesAdded(user: user))
        }
    }

    func signIn(auth: UserAuthInfo, isNewUser: Bool) async throws {
        let creationVersion = isNewUser ? Utilities.appVersion : nil
        let user = UserModel(auth: auth, creationVersion: creationVersion)
        logger?.trackEvent(event: Event.logInStart(user: user))

        // Save user document
        try await userSyncEngine.saveDocument(user)
        logger?.trackEvent(event: Event.logInSuccess(user: user))

        // Start listening to this user document
        try await userSyncEngine.startListening(documentId: auth.uid)

        // Add user properties to analytics
        if let currentUser, let logManager = logger as? LogManager {
            logManager.addUserProperties(dict: currentUser.eventParameters, isHighPriority: true)
        }
    }

    func getUser() async throws -> UserModel {
        try await userSyncEngine.getDocumentAsync()
    }

    func saveOnboardingCompleteForCurrentUser() async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.didCompleteOnboarding.rawValue: true
        ])
    }

    func saveUserName(name: String) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedName.rawValue: name
        ])
    }

    func saveUserEmail(email: String) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedEmail.rawValue: email
        ])
    }

    func saveUserProfileImage(image: UIImage) async throws {
        let uid = try userSyncEngine.getDocumentId()

        // Upload the image
        let path = "users/\(uid)/profile"
        let url = try await FirebaseImageUploadService().uploadImage(image: image, path: path)

        // Update user document with image url
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.submittedProfileImage.rawValue: url.absoluteString
        ])
    }

    func saveUserFCMToken(token: String) async throws {
        try await userSyncEngine.updateDocument(data: [
            UserModel.CodingKeys.fcmToken.rawValue: token
        ])
    }

    func signOut() {
        userSyncEngine.stopListening()
        logger?.trackEvent(event: Event.signOut)
    }

    func deleteCurrentUser() async throws {
        logger?.trackEvent(event: Event.deleteAccountStart)

        let uid = try currentUserId()
        guard let documentId = try? userSyncEngine.getDocumentId(), uid == documentId else {
            throw UserManagerError.userIdChanged
        }

        try await userSyncEngine.deleteDocument()
        logger?.trackEvent(event: Event.deleteAccountSuccess)

        signOut()
    }

    private func currentUserId() throws -> String {
        guard let uid = currentUser?.userId else {
            throw UserManagerError.noUserId
        }
        return uid
    }

    enum UserManagerError: LocalizedError {
        case noUserId
        case userIdChanged
    }

    static func mock(user: UserModel? = nil) -> UserManager {
        UserManager(userSyncEngine: DocumentSyncEngine<UserModel>(
            remote: MockRemoteDocumentService(document: user),
            managerKey: "UserMan",
            enableLocalPersistence: false
        ))
    }

    enum Event: DataSyncLogEvent {
        case userPropertiesAdded(user: UserModel)
        case logInStart(user: UserModel?)
        case logInSuccess(user: UserModel?)
        case signOut
        case deleteAccountStart
        case deleteAccountSuccess

        var eventName: String {
            switch self {
            case .userPropertiesAdded:      return "UserMan2_UserPropertiesAdded"
            case .logInStart:               return "UserMan2_LogIn_Start"
            case .logInSuccess:             return "UserMan2_LogIn_Success"
            case .signOut:                  return "UserMan2_SignOut"
            case .deleteAccountStart:       return "UserMan2_DeleteAccount_Start"
            case .deleteAccountSuccess:     return "UserMan2_DeleteAccount_Success"
            }
        }

        var parameters: [String: Any]? {
            switch self {
            case .userPropertiesAdded(user: let user):
                return user.eventParameters
            case .logInStart(user: let user), .logInSuccess(user: let user):
                return user?.eventParameters
            default:
                return nil
            }
        }

        var type: DataLogType {
            switch self {
            default:
                return .analytic
            }
        }
    }
}
