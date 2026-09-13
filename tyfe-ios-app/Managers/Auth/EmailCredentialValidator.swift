//
//  EmailCredentialValidator.swift
//  tyfe-ios-app
//
//  Shared client-side validation for email + password entry. The server remains
//  the source of truth; this only avoids obvious round-trips.
//

import Foundation

enum EmailCredentialValidator {

    static let minimumPasswordLength = 6

    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("@"), !trimmed.hasSuffix(".") else { return false }
        guard let atIndex = trimmed.firstIndex(of: "@") else { return false }
        guard trimmed[trimmed.index(after: atIndex)...].contains(".") else { return false }
        guard trimmed[..<atIndex].count >= 1 else { return false }
        return true
    }

    static func isValidPassword(_ password: String) -> Bool {
        password.count >= minimumPasswordLength
    }
}
