//
//  SupabaseUserAuthMapper.swift
//  tyfe-ios-app
//
//  Maps Supabase auth objects into the app's SwiftfulAuthenticating user info.
//

#if !MOCK && canImport(Supabase)
import Foundation
import Supabase
import SwiftfulAuthenticating

enum SupabaseUserAuthMapper {

    static func userAuthInfo(from session: Session) -> UserAuthInfo {
        userAuthInfo(from: session.user)
    }

    static func userAuthInfo(from user: User) -> UserAuthInfo {
        let providers = (user.identities ?? []).compactMap { authProvider(for: $0.provider) }
        return UserAuthInfo(
            uid: user.id.uuidString,
            email: user.email,
            isAnonymous: user.isAnonymous,
            authProviders: providers,
            displayName: user.userMetadata["display_name"]?.stringValue,
            phoneNumber: user.phone,
            creationDate: user.createdAt,
            lastSignInDate: user.lastSignInAt
        )
    }

    static func authProvider(for providerId: String) -> AuthProviderOption? {
        switch providerId {
        case "apple": return .apple
        case "google": return .google
        case "email": return .email
        case "phone": return .phone
        default: return nil
        }
    }
}
#endif
